function label = detect_oracle(param, model, xi, yi)
% do loss-augmented detection on a given example (xi,yi) using
% model.w as parameter. Param is ignored (included for standard
% interface). The loss used is normalized Hamming loss.
% If yi is not given, then MAP decoding without the loss term.
%
% INPUT: 
% param = {overlap, thresh, latent}, where latent == loss-aug
% model = 
% xi = {pyra}
% yi = {bbox}
% OUTPUT:
% label = {bbox, level, ex}
%
% TODO: support mixture parts

%% DEBUG code
% ovmasks = ovmask;
% ovmasks = repmat(ovmasks, [1,1,numparts]);
% for j = 1:numparts
%     ovmasks(:,:,j) = testoverlap(parts(j).sizx(1),parts(j).sizy(1),pyra,rlevel,bbox.xy(j,:),overlap);
%     figure(j); imagesc(ovmasks(:,:,j));
% end
% ovmask = sum(ovmasks, 3);

%%
latent = false;
overlap = param.overlap;
%thresh = param.thresh;
pyra = xi.pyra;

if nargin > 3 && ~isempty(yi.bbox)
  % do loss augmentation
  latent = true;
  bbox = yi.bbox;
end

% Compute the feature pyramid and prepare filter
interval = model.interval;
levels = 1:length(pyra.feat);
%levels = levels(randperm(length(levels))); % random increase robustness

% Cache various statistics derived from model
model = vec2model(model.w, model); % NOTE: update model.filter to do Inference
[components,filters,resp] = modelcomponents(model,pyra);
boxes = zeros(length(levels),length(components{1})*4+2);
boxes(:,end) = -Inf;

% exs and ex are feature_map
exs = cell(1,length(levels));
ex.blocks = [];

% DEBUG
allskipflags = zeros(1,length(levels));

% Iterate over random permutation of scales and components,
for rlevel = levels
  % Iterate through mixture components
  for c  = randperm(length(model.components))
    parts = components{c};
    numparts = length(parts);

    % Skip if there is no overlap of root filter with bbox
    if latent
      skipflag = 0;
      for k = 1:numparts
        % because all mixtures for one part is the same size, we only need to do this once
        ovmask = testoverlap(parts(k).sizx(1),parts(k).sizy(1),...
          pyra,rlevel,bbox(k,:),overlap);
        if ~any(ovmask)
          skipflag = 1;
          break;
        end
      end
      if skipflag == 1 % DEBUG
        allskipflags(rlevel) = 1;
        continue;
      end
    end % latent
    
    level = rlevel-parts(k).scale*interval; % scale is set to 0, so parts in same level as root
    if isempty(resp{level})
        resp{level} = fconv(pyra.feat{level},filters,1,length(filters));
    end
    
    % 1) unary scores and loss augmentation
    for k = 1:numparts
      f = parts(k).filterid;   
      for fi = 1:length(f)
        % loss augment
        if latent
            ovmask = testoverlap(parts(k).sizx(fi),parts(k).sizy(fi),...
                pyra,rlevel,bbox(fi,:),overlap);
            ovmask = ~ovmask;
            resp{level}{f(fi)}(ovmask) = resp{level}{f(fi)}(ovmask) + 1/numparts;
        end       
        parts(k).score(:,:,fi) = resp{level}{f(fi)};
      end % fi
      parts(k).level = level;
      
      if all(cellfun(@isempty, resp))
        error('!!!!! No quantized location overlap with bbox !!!!!!');
      end
    end % numparts
    
    % 2) Walk from leaves to root of tree, passing message to parent
    for k = numparts:-1:1 % make sure this is reverse of topological order
      if (param.fix_def)
        parts(k).w = repmat([0.01 0 0.01 0]', 1, length(parts(k).defid));
      end
      par = parts(k).parent;
      assert(~isempty(par));
      if par == 0
        % Add bias to root score
        parts(k).score = parts(k).score + parts(k).b;
        continue
      end
      assert(all(par > 0));
      % pass msg to all parents
      for pp = par
        [msg,parts(k).Ix,parts(k).Iy,parts(k).Im] = passmsg(parts(k),parts(pp));
        parts(pp).score = parts(pp).score + msg;
        %fprintf('>>> detect_oracle.msgpass.k %d\n',k);
      end
    end % 2)

    % 3) find max location for each root
    val = -Inf; [Y,X,Im] = deal([]);
    for k = 1:numparts
      if any(parts(k).parent > 0)
        continue
      end
      [rscore tIm] = max(parts(k).score,[],3); % tIm: mix
      [tval,tind] = max(rscore(:));
      if tval > val
        val = tval;
        [Y,X] = ind2sub(size(rscore),tind);
        Im = tIm;
      end
    end
    
    % 4) Walk back down tree following pointers
    for i = 1:length(X)
      x = X(i);
      y = Y(i);
      m = Im(y,x); % mixture
      [box,exs{rlevel}] = backtrack(x,y,m,parts,pyra,ex,latent);
      boxes(rlevel,:) = [box c rscore(y,x)];
    end
  end % c
end % rlevel

if all(boxes(:,1:end-2) == 0)
  error('!!! All boxes are empty !!!\n');
end

[~,ii] = max(boxes(:,end)); % TODO: test which better: max or random (ii = end)
boxes = boxes(ii,:);
%[boxes] = nms(boxes,0.3);
label.bbox = boxes;

if latent  
  label.level = ii;
  label.ex = exs{label.level};
  if isempty(label.ex) % DEBUG
    dbstop
  end
end


%% helper functions

% Given a 2D array of filter scores 'child',
% (1) Apply distance transform
% (2) Shift by anchor position of part wrt parent
% (3) Downsample if necessary
function [score,Ix,Iy,Im] = passmsg(child,parent)

K   = length(child.filterid); % # of mixtures in child
Ny  = size(parent.score,1);
Nx  = size(parent.score,2);  
Ix0 = zeros([Ny Nx K]);
Iy0 = zeros([Ny Nx K]);
[Ix0,Iy0,score0] = deal(zeros([Ny Nx K]));

for k = 1:K
  if child.w(1,k) == 0
    child.w(1,k) = child.w(1,k) + 1e-5;
  end
  if child.w(3,k) == 0
    child.w(3,k) = child.w(3,k) + 1e-5;
  end
	[score0(:,:,k),Ix0(:,:,k),Iy0(:,:,k)] = ...
    shiftdt(child.score(:,:,k), child.w(1,k), child.w(2,k), child.w(3,k), child.w(4,k),...
      child.startx(k),child.starty(k),Nx,Ny,child.step);
end

% At each parent location, for each parent mixture 1:L, compute best child mixture 1:K
L  = length(parent.filterid);
N  = Nx*Ny;
i0 = reshape(1:N,Ny,Nx);
[score,Ix,Iy,Im] = deal(zeros(Ny,Nx,L));
for l = 1:L
	b = child.b(1,l,:);
	[score(:,:,l),I] = max(bsxfun(@plus,score0,b),[],3);
	i = i0 + N*(I-1);
	Ix(:,:,l)    = Ix0(i);
	Iy(:,:,l)    = Iy0(i);
	Im(:,:,l)    = I;
end


% Backtrack through dynamic programming messages to estimate part locations
% and the associated feature vector  
function [box,ex] = backtrack(x,y,mix,parts,pyra,ex,write)

numparts = length(parts);
ptr = zeros(numparts,3);
box = zeros(numparts,4);
k   = 1;
p   = parts(k);
ptr(k,:) = [x y mix];
scale = pyra.scale(p.level);
x1  = (x - 1 - pyra.padx)*scale+1;
y1  = (y - 1 - pyra.pady)*scale+1;
x2  = x1 + p.sizx(mix)*scale - 1;
y2  = y1 + p.sizy(mix)*scale - 1;
box(k,:) = [x1 y1 x2 y2];

if write
	%ex.id(3:5) = [p.level round(x+p.sizx(mix)/2) round(y+p.sizy(mix)/2)];
  ex.level = p.level;
	ex.blocks = [];
	ex.blocks(end+1).i = p.biasI;
	ex.blocks(end).x   = 1;
	f  = pyra.feat{p.level}(y:y+p.sizy(mix)-1,x:x+p.sizx(mix)-1,:);
	ex.blocks(end+1).i = p.filterI(mix);
	ex.blocks(end).x   = f;
end
for k = 2:numparts
	p   = parts(k);
	par = p.parent;
	x   = ptr(par,1);
	y   = ptr(par,2);
	mix = ptr(par,3);
	ptr(k,1) = p.Ix(y,x,mix);
	ptr(k,2) = p.Iy(y,x,mix);
	ptr(k,3) = p.Im(y,x,mix);
	scale = pyra.scale(p.level);
	x1  = (ptr(k,1) - 1 - pyra.padx)*scale+1;
	y1  = (ptr(k,2) - 1 - pyra.pady)*scale+1;
	x2  = x1 + p.sizx(ptr(k,3))*scale - 1;
	y2  = y1 + p.sizy(ptr(k,3))*scale - 1;
	box(k,:) = [x1 y1 x2 y2];
	
	if write
		ex.blocks(end+1).i = p.biasI(mix,ptr(k,3));
		ex.blocks(end).x   = 1;
		ex.blocks(end+1).i = p.defI(ptr(k,3));
		ex.blocks(end).x   = defvector(x,y,ptr(k,1),ptr(k,2),ptr(k,3),p);
		x   = ptr(k,1);
		y   = ptr(k,2);
		mix = ptr(k,3);
		f   = pyra.feat{p.level}(y:y+p.sizy(mix)-1,x:x+p.sizx(mix)-1,:);
		ex.blocks(end+1).i = p.filterI(mix);
		ex.blocks(end).x = f;
	end
end
box = reshape(box',1,4*numparts);
