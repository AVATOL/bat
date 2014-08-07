function label = rpm_oracle2(param, model, xi, yi)
% do loss-augmented detection on a given example (xi,yi) using
% model.w as parameter. Param is ignored (included for standard
% interface). The loss used is normalized Hamming loss.
% 
% If yi is not given, then standard prediction is done (i.e. MAP decoding
% without the loss term).
%
% INPUT: 
% param = {overlap, thresh, latent}, where latent == loss-aug
% model
% xi = {pyra}
% yi = {bbox}
% OUTPUT:
% label = {bbox, level, ex}
%
% TODO: support mixture parts
%%
global Ix_cache Iy_cache It_cache Im_cache Is_cache comb_cache

INF = 1e10;
latent = false;
overlap = param.overlap;
%thresh = param.thresh;
pyra = xi.pyra;

if nargin > 3 && ~isempty(yi.bbox)
  % latent means to do loss augmentation
  latent = true;
  bbox = yi.bbox;
end

% Compute the feature pyramid and prepare filter
interval = model.interval;
levels = 1:length(pyra.feat);

% get model components
model = vec2model(model.w, model); % NOTE: update model.filter to do inference
[components,filters,resp] = parsemodel(model,pyra);
boxes = zeros(length(levels),length(components{1})*4+2);
boxes(:,end) = -Inf;

% exs and ex are feature_map
exs = cell(1,length(levels));
ptr = cell(1,length(levels));
subadj = cell(1,length(levels));
ex.blocks = [];

% DEBUG
allskipflags = zeros(1,length(levels));

% Iterate over random permutation of scales and components,
for rlevel = levels
  % Iterate through mixture components (viewpoints)
  for c  = randperm(length(model.components))
    parts = components{c};
    numparts = length(parts);

    % Skip if there is no overlap of root filter with bbox
    % TODO: overlap is critical, handling large-scale windows problematic
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
    
    % 1) unary scores and loss augmentation
    for k = 1:numparts
      f = parts(k).filterid;
      level = rlevel-parts(k).scale*interval; % scale is set to 0, so parts in same level as root
      if isempty(resp{level})
        resp{level} = fconv(pyra.feat{level},filters,1,length(filters));
      end

      for fi = 1:length(f) % mixtures
        % loss augment
        if latent
            ovmask = testoverlap(parts(k).sizx(fi),parts(k).sizy(fi),pyra,rlevel,bbox(k,:),overlap);
            ovmask = ~ovmask;
            resp{level}{f(fi)}(ovmask) = resp{level}{f(fi)}(ovmask) + 1/numparts;
        end       
        % theta_v(yv,xv,tv,kv)
        parts(k).score(:,:,2,fi) = resp{level}{f(fi)}; % tv = 2
        parts(k).score(:,:,1,fi) = parts(k).on(fi); % tv = 1
      end % fi
      parts(k).level = level;
      
      if all(cellfun(@isempty, resp))
        error('!!!!! No quantized location overlap with bbox !!!!!!');
      end      
    end % for numparts 
    
    % 2) Walk from leaves to root of tree, passing message to parent
    adj = model.adj;
    addpath util/graph/
    tporder = topological_sort(adj);
    msg_cache = cell(size(adj));
    Ix_cache = cell(size(adj));
    Iy_cache = cell(size(adj));
    It_cache = cell(size(adj)); % tv
    Im_cache = cell(size(adj)); % kv i.e. mixture
    Is_cache = cell(1,size(adj,1)); % tvu
    comb_cache = cell(1,size(adj,1)); % all combs of children
    
    for k = tporder % make sure this is reverse of topological order
      % compute score of itself by adding coming messages (decide t_vu)
      % score_v(yv,xv,tv,kv) 
      % = theta_v(yv,xv,tv,kv) + max_{tv.} sum_u msg_{u->v}(yv,xv,tv,tvu,kv)
      % theta_v(yv,xv,tv,kv) = w_v^{kv}*phi(yv,xv)   if tv = 2
      %                      = o_v^{kv}              if tv = 1
      % backpointer: Is(yv,xv,tv,kv) = {tv.}^*(yv,xv,tv,kv)
      Ny  = size(parts(k).score,1);
      Nx  = size(parts(k).score,2); 
      L = length(parts(k).filterid);
      
      children = adj(:,k) == 1;
      combs = cartesianProduct(repmat({[0+1 1+1]},[1 sum(children)])); % tvu
      cmsgs = msg_cache(children,k); % (yv,xv,tv,tvu,kv)

      % constrain loop that allow combs form tree structure only
      if ~isempty(model.tvu_vis{k})
          combs = model.tvu_vis{k};
      end
      
      ncb = max(1,size(combs,1));
      %Is = zeros(Ny,Nx,2,L);
      comb_msg = zeros(Ny,Nx,2,L,ncb); % (y,x,tv,kv)
      % TODO: now DAG is assumed to be a tree. check tree constraint (single parent)
      for ci = 1:size(combs,1)
        for u = 1:size(combs,2)
          if isempty(cmsgs{u})
            continue
          end
          % get all combinations of coming msgs (tvu)
          comb_msg(:,:,:,:,ci) = comb_msg(:,:,:,:,ci) + squeeze(cmsgs{u}(:,:,:,combs(ci,u),:));
        end
      end
      [comb_msg,Is_cache{k}] = max(comb_msg,[],5); % local greedy maximizing over combs
      
      if ~isempty(comb_msg)
        parts(k).score = parts(k).score + comb_msg; % (y,x,tv,kv)
      end
      comb_cache{k} = combs;
      
      % compute forward messages to all parents
      % msg_{u->v}(yv,xv,tv,tvu,kv)
      if (param.fix_def)
        parts(k).w = repmat([0.01 0 0.01 0]', [1,size(parts(k).defid)]);
      end
      par = parts(k).parent;
      assert(~isempty(par));
      
      % root: no passing only add bias
      % score_r(yr,xr,tr,kr) += b_r(:,1,1)
      if par == 0
        b = parts(k).b(:,1,1);
        b = shiftdim(b,-3);
        parts(k).score = bsxfun(@plus,parts(k).score,b);
        continue
      end
      
      % non-root: pass messages to all parents
      assert(all(par > 0));
      for pp = par
        [msg_cache{k,pp},Ix_cache{k,pp},Iy_cache{k,pp},It_cache{k,pp},Im_cache{k,pp}] ...
          = passmsg(parts(k),parts(pp));

        % parts that always visible
        if model.tu_vis(k) 
            It_cache{k,pp} = It_cache{k,pp} .* 0 + 2;
        end
      end
    end % message passing

    % 3) find max location for each root and use the root with max score
    val = -Inf; [Y,X,It,Im] = deal([]);
    for k = 1:numparts
      if any(parts(k).parent > 0)
        continue
      end
      [rscore1 tIm] = max(parts(k).score,[],4);
      [rscore tIt] = max(rscore1,[],3);
      [tval,tind] = max(rscore(:));
      if tval > val
        val = tval;
        [Y,X] = ind2sub(size(rscore),tind);
        Im = tIm; % Im = (Ny,Nx,Dv)
        It = tIt; % It = (Ny,Nx)
        Is = Is_cache{k};
      end
    end

    % parts that always visible
    if model.tu_vis(1)
        It = It .* 0 + 2;
    end
    
    % 4) Walk back down tree following pointers
    for i = 1:length(X) % TODO: length correct?
      x = X(i);
      y = Y(i);
      tr = It(y,x); % t_r
      m = Im(y,x,tr); % mixture
      ts = Is(y,x,tr,m);
      [box,exs{rlevel},ptr{rlevel},subadj{rlevel}] = backtrack(x,y,tr,m,ts,adj,parts,pyra,ex,latent); % write = latent
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
  label.ptr = ptr{label.level};
  label.subadj = subadj{label.level};

  if isempty(label.ex) % DEBUG
    dbstop
  end
end

%% helper functions

function [msg,Ix,Iy,It,Ik] = passmsg(child,parent)
% Given a 2D array of filter scores 'child',
% (1) Apply distance transform
% (2) Shift by anchor position of part wrt parent
% (3) Downsample if necessary
% msg_{u->v}(yv,xv,tv,tvu,kv) 
% = max_ku [ b_vu(kv,ku)
%            + max_{yu,xu,tu} ( theta(yv,xv,yu,xu,tv,tu,tvu,kv,ku)
%                               + score_u(yu,xu,tu,ku) ) ]
% backpointers: (1) Ix, Iy <- xu^*, yu^*
%               (2) It <- tu^*
%               (3) Ik <- ku^*
% Note that all backpointers have the same dim as msg_{u->v}
% e.g., It(yv,xv,tv,tvu,kv) = tu^*(yv,xv,tv,tvu,kv)

whichpar = parent.id == child.parent;
assert(sum(whichpar) == 1);
K   = length(child.filterid);
Ny  = size(parent.score,1);
Nx  = size(parent.score,2);  
Du  = 2;
Duv = 2;
[Ix0,Iy0,It0,msg0] = deal(zeros([Ny Nx Du Duv K]));

% max_tu,xu, iff tv = tu = tvu = 2, theta_vu will be used, otherwise o_vu 
for tv = 1:Du
  for tvu = 1:Duv
    for k = 1:K
      % if o_vu used, max is indep of yv,xv,tv,tvu,kv
      oscore = zeros(1,Du);
      oind = zeros(1,Du);
      
      for tu = 1:Du % exception tv=tvu=2 later
        childsc = child.score(:,:,tu,k); % score_u(yu,xu,tu,ku)
        [oscore(tu),oind(tu)] = max(childsc(:));
      end % for tu

      % oscore = (Ny,Nx,Du)
      oscore = shiftdim(oscore,-1);
      oind = shiftdim(oind,-1);
      oscore = oscore + child.om(k,whichpar); % o_vu(k,v)
      oscore = repmat(oscore,[Ny Nx]);
      oind = repmat(oind,[Ny Nx]);
      [oiy,oix] = ind2sub([Ny Nx],oind);

      if tv == 2 && tvu == 2
        if child.w(1,k,whichpar) == 0
          child.w(1,k,whichpar) = child.w(1,k,whichpar) + 1e-5;
        end
        if child.w(3,k,whichpar) == 0
          child.w(3,k,whichpar) = child.w(3,k,whichpar) + 1e-5;
        end
        w1 = child.w(1,k,whichpar); w2 = child.w(2,k,whichpar); 
        w3 = child.w(3,k,whichpar); w4 = child.w(4,k,whichpar);
        stx = child.startx(k,whichpar); sty = child.starty(k,whichpar);
        % tu = 2
        [dtscore,dtix,dtiy] = shiftdt(child.score(:,:,2,k),w1,w2,w3,w4,stx,sty,Nx,Ny,child.step);
        oscore(:,:,2) = dtscore;
        oiy(:,:,2) = dtiy;
        oix(:,:,2) = dtix;
      end % if

      [msg0(:,:,tv,tvu,k),itu] = max(oscore,[],3); % return Ny by Nx matrix
      It0(:,:,tv,tvu,k) = itu;
      N = Ny*Nx;
      i0 = reshape(1:N,Ny,Nx);
      ind = i0 + N*(itu-1); % think about if itu are all 1 or 2
      Ix0(:,:,tv,tvu,k) = oix(ind); % since ind is Ny by Nx, so as oix(ind)
      Iy0(:,:,tv,tvu,k) = oiy(ind);
    end % for k
  end % for tvu
end % for tv

% b_{ij}^{ki,kj}
% At each parent location, for each parent mixture 1:L, compute best child mixture 1:K
L  = length(parent.filterid);
N  = Nx*Ny*Du*Duv;
i0 = reshape(1:N,[Ny Nx Du Duv]);
[msg,Ix,Iy,It,Ik] = deal(zeros([Ny Nx Du Duv L]));

for l = 1:L
	b = child.b(:,l,whichpar);
	b = shiftdim(b,-4); % [b1; b2] to [b1 b2] is shiftdim(b,-1)
	[msg(:,:,:,:,l),I] = max(bsxfun(@plus,msg0,b),[],5);
	i = i0 + N*(I-1); % i is 4-dim array
	Ix(:,:,:,:,l)    = Ix0(i);
	Iy(:,:,:,:,l)    = Iy0(i);
    It(:,:,:,:,l)    = It0(i);
	Ik(:,:,:,:,l)    = I;
end


% Backtrack through dynamic programming messages to estimate part locations
% and the associated feature vector  
function [box,ex,ptr,subadj] = backtrack(x,y,tv,mix,ts,adj,parts,pyra,ex,write)
% (x,y) is root location
% ex: feature map
%
% OUTPUT:
% ex: feature map
% ptr: (x y tv mix)
% subadj: 1-absent, 2-present

global Ix_cache Iy_cache It_cache Im_cache Is_cache comb_cache

numparts = length(parts);
ptr = zeros(numparts,4);
box = zeros(numparts,4);
%combs = cell(numparts,1);
flags = zeros(numparts,1); % flag which edge is invisiable-1, visiable-2
subadj = zeros(size(adj));

torder = topological_sort(adj);
k   = torder(end);
flags(k) = 2;
children = find(adj(:,k) == 1);
ptr(k,:) = [x y tv mix];
subadj(children,k) = comb_cache{k}(ts,:)';

comb = comb_cache{k}(ts,:) == 2;
flags(children(comb)) = 2;
flags(children(~comb)) = 1;
%subadj(children(comb),k) = 1;
p   = parts(k);

scale = pyra.scale(p.level);
x1  = (x - 1 - pyra.padx)*scale+1;
y1  = (y - 1 - pyra.pady)*scale+1;
x2  = x1 + p.sizx(mix)*scale - 1;
y2  = y1 + p.sizy(mix)*scale - 1;
box(k,:) = [x1 y1 x2 y2];

if write % TODO: p.xxI and check where ex has been used
	%ex.id(3:5) = [p.level round(x+p.sizx(mix)/2) round(y+p.sizy(mix)/2)];
    ex.level = p.level;
	ex.blocks = [];
	ex.blocks(end+1).i = p.biasI;
	ex.blocks(end).x   = 1;
    if tv == 2
      f  = pyra.feat{p.level}(y:y+p.sizy(mix)-1,x:x+p.sizx(mix)-1,:);
      tf = 0;
    elseif tv == 1
      f = zeros(p.sizy, p.sizx, 32);
      tf = 1;
    else
      error('something wrong in backprop!');
    end
    ex.blocks(end+1).i = p.filterI(mix);
    ex.blocks(end).x   = f;
    ex.blocks(end+1).i = p.onI;
    ex.blocks(end).x   = tf;
end

for k = torder(end-1:-1:1)
    assert(flags(k) > 0);
    
    children = find(adj(:,k) == 1);
    p   = parts(k);
    par = p.parent;
	x   = ptr(par,1);
	y   = ptr(par,2);
    tv  = ptr(par,3);
	mix = ptr(par,4);
    tvu = subadj(k,par);
  
    ptr(k,1) = Ix_cache{k,par}(y,x,tv,tvu,mix);
	ptr(k,2) = Iy_cache{k,par}(y,x,tv,tvu,mix);
	ptr(k,3) = It_cache{k,par}(y,x,tv,tvu,mix);
    ptr(k,4) = Im_cache{k,par}(y,x,tv,tvu,mix);
  
	scale = pyra.scale(p.level);
	x1  = (ptr(k,1) - 1 - pyra.padx)*scale+1;
	y1  = (ptr(k,2) - 1 - pyra.pady)*scale+1;
	x2  = x1 + p.sizx(ptr(k,4))*scale - 1;
	y2  = y1 + p.sizy(ptr(k,4))*scale - 1;
	box(k,:) = [x1 y1 x2 y2];
  
    if isempty(children) 
      continue
    end
    ts = Is_cache{k}(y,x,tv,mix);
    subadj(children,k) = comb_cache{k}(ts,:)';

    % fifo = [fifo children(combs)];
    comb = comb_cache{k}(ts,:) == 2;
    flags(children(comb)) = 2;
    flags(children(~comb)) = 1;
	
	if write
		ex.blocks(end+1).i = p.biasI(ptr(k,4),mix); % TODO choose right par, see parsemodel.m 
		ex.blocks(end).x   = 1;
		
		x   = ptr(k,1);
		y   = ptr(k,2);
        tu  = ptr(k,3);
		mix = ptr(k,4);
        if tu == 2
          f  = pyra.feat{p.level}(y:y+p.sizy(mix)-1,x:x+p.sizx(mix)-1,:);
          tf = 0;
        elseif tu == 1
          f = zeros(p.sizy, p.sizx, 32);
          tf = 1;
        else
          error('something wrong in backprop!');
        end
		ex.blocks(end+1).i = p.filterI(mix);
		ex.blocks(end).x = f;
        ex.blocks(end+1).i = p.onI;
        ex.blocks(end).x   = tf;
        
        if tu == 2 && tv == 2 && tvu == 2
          df  = defvector(x,y,ptr(k,1),ptr(k,2),ptr(k,4),p);
          tdf = 0;
        elseif tu == 1 || tv == 1 || tvu == 1
          df = [0 0 0 0];
          tdf = 1;
        else
          error('something wrong in backprop!');
        end
        ex.blocks(end+1).i = p.defI(ptr(k,4));
	    ex.blocks(end).x   = df; % TODO: choose right par
        ex.blocks(end+1).i = p.omI;
        ex.blocks(end).x   = tdf;
	end % if write
end % k
box = reshape(box',1,4*numparts);

% enumerate all combinations equivalent tp cartesian product
function combs = cartesianProduct(domains)
% e.g., domains = repmat({[0 1]}, [1,3])
if isempty(domains)
  combs = [];
  return
end
if size(domains,2) == 1
  combs = domains{1}';
  return
end
combs = cell(size(domains));
[combs{:}] = ndgrid(domains{:});
combs = cell2mat(cellfun(@(x) x(:), combs, 'UniformOutput',false));
combs = sortrows(combs, 1:numel(domains));
