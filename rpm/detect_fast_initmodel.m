function [ov,ovu,boxes,pmsgs,parts,bkptr] = detect_fast_initmodel(im, model, bbox, lvl)
% boxes = detect(im, model, thresh)
% Detect objects in input using a model and a score threshold.
% Higher threshold leads to fewer detections.
%
% The function returns a matrix with one row per detected object.  The
% last column of each row gives the score of the detection.  The
% column before last specifies the component used for the detection.
% Each set of the first 4 columns specify the bounding box for a part

% Compute the feature pyramid and prepare filter
pyra     = featpyramid(im,model);
interval = model.interval;

if nargin > 3
  levels   = lvl;
else
  levels   = 1:length(pyra.feat);
end
latent = 1;
if nargin < 3
  latent = 0;
  bbox = [];
end

% Cache various statistics derived from model
[components,filters,resp] = modelcomponents(model,pyra);
boxes = zeros(10000,length(components{1})*4+2);
cnt   = 0;
val = -1e10;
numparts = length(model.components{1});
ov = ones(1,numparts)*1e10;
ovu = ones(1,numparts)*1e10;
ovu(1) = 0;

% Iterate over scales and components,
for rlevel = levels,
  for c  = 1:length(model.components),
    parts    = components{c};
    numparts = length(parts);
    
    if latent
      skipflag = 0;
      for k = 1:numparts
        % because all mixtures for one part is the same size, we only need to do this once
        ovmask = testoverlap(parts(k).sizx(1),parts(k).sizy(1),...
          pyra,rlevel,bbox(k,:),0.5);
        if ~any(ovmask)
          skipflag = 1;
          break;
        end
      end
      if skipflag == 1
        continue;
      end
    end % latent

    % Local scores
    for k = 1:numparts,
      f     = parts(k).filterid;
      level = rlevel-parts(k).scale*interval;
      if isempty(resp{level}),
        resp{level} = fconv(pyra.feat{level},filters,1,length(filters));
      end
      for fi = 1:length(f)
        parts(k).score(:,:,fi) = resp{level}{f(fi)};
      end
      parts(k).level = level;
    end
    
    % Walk from leaves to root of tree, passing message to parent
    pmsgs = cell(1,numparts);
    for k = numparts:-1:2,
      par = parts(k).parent;
      pmsgs{k} = passmsg(parts(k),parts(par));
    end
    
    for k = numparts:-1:2,
      par = parts(k).parent;
      [msg,parts(k).Ix,parts(k).Iy,parts(k).Ik] = passmsg(parts(k),parts(par));
      parts(par).score = parts(par).score + msg;
    end

    % Add bias to root score
    parts(1).score = parts(1).score + parts(1).b;
    [rscore Ik]    = max(parts(1).score,[],3);

    % Walk back down tree following pointers
    %[Y,X] = find(rscore >= thresh);
    [tval,tind] = max(rscore(:));
    if tval > val
      [Y,X] = ind2sub(size(rscore),tind);
  %     if length(X) > 1,
        I   = (X-1)*size(rscore,1) + Y;
        assert(tval == rscore(I));
        [box bkptr] = backtrack(X,Y,Ik(I),parts,pyra);
        i   = cnt+1:cnt+length(I);
        boxes(i,:) = [box repmat(c,length(I),1) rscore(I)];
  %       if nargout >= 2
  %           for t = 1:numparts
  %               % TODO: parts now distributed differently from root
  %               pmsgs(i,t) = parts(t).score(I);
  %           end
  %       end
        cnt = i(end);
  %     end
    end
    
    if ~isempty(bbox) % use GT
      xy = bbox';
      scale = pyra.scale(rlevel);
      % parts
      for k = 1:numparts
        bkptr(1,k,1) = ceil((xy(1,k)-1) / scale + pyra.padx + 1);
        bkptr(1,k,2) = ceil((xy(2,k)-1) / scale + pyra.pady + 1);
      end
    end
    
    for k = 1:numparts
      y = bkptr(1,k,2);
      x = bkptr(1,k,1);
      %ov(k) = max(ov(k),parts(k).score(y,x));
      ov(k) = min(ov(k),resp{rlevel}{1}(y,x));
      if k > 1
        ovu(k) = min(ovu(k),pmsgs{k}(y,x) - ov(k));
      end
    end
  end
end

boxes = boxes(1:cnt,:);
% if nargout >= 2
%     pmsgs = pmsgs(1:cnt,:);
% end
      

% Cache various statistics from the model data structure for later use  
function [components,filters,resp] = modelcomponents(model,pyra)
  components = cell(length(model.components),1);
  for c = 1:length(model.components),
    for k = 1:length(model.components{c}),
      p = model.components{c}(k);
      [p.w,p.defI,p.starty,p.startx,p.step,p.level,p.Ix,p.Iy] = deal([]);
      [p.scale,p.level,p.Ix,p.Iy] = deal(0);
      
      % store the scale of each part relative to the component root
      par = p.parent;      
      assert(par < k);
      p.b = [model.bias(p.biasid).w];
      p.b = reshape(p.b,[1 size(p.biasid)]);
      p.biasI = [model.bias(p.biasid).i];
      p.biasI = reshape(p.biasI,size(p.biasid));
      p.sizx  = zeros(length(p.filterid),1);
      p.sizy  = zeros(length(p.filterid),1);
      
      for f = 1:length(p.filterid)
        x = model.filters(p.filterid(f));
        [p.sizy(f) p.sizx(f) foo] = size(x.w);
%         p.filterI(f) = x.i;
      end
      for f = 1:length(p.defid)	  
        x = model.defs(p.defid(f));
        p.w(:,f)  = x.w';
        p.defI(f) = x.i;
        ax  = x.anchor(1);
        ay  = x.anchor(2);    
        ds  = x.anchor(3);
        p.scale = ds + components{c}(par).scale;
        % amount of (virtual) padding to hallucinate
        step     = 2^ds;
        virtpady = (step-1)*pyra.pady;
        virtpadx = (step-1)*pyra.padx;
        % starting points (simulates additional padding at finer scales)
        p.starty(f) = ay-virtpady;
        p.startx(f) = ax-virtpadx;      
        p.step   = step;
      end
      components{c}(k) = p;
    end
  end
  
  resp    = cell(length(pyra.feat),1);
  filters = cell(length(model.filters),1);
  for i = 1:length(filters),
    filters{i} = model.filters(i).w;
  end

% Given a 2D array of filter scores 'child',
% (1) Apply distance transform
% (2) Shift by anchor position of part wrt parent
% (3) Downsample if necessary
function [score,Ix,Iy,Ik] = passmsg(child,parent)
  INF = 1e10;
  K   = length(child.filterid);
  Ny  = size(parent.score,1);
  Nx  = size(parent.score,2);  
  [Ix0,Iy0,score0] = deal(zeros([Ny Nx K]));

  for k = 1:K
    if child.w(1,k) == 0
      child.w(1,k) = child.w(1,k) + 1e-5;
    end
    if child.w(3,k) == 0
      child.w(3,k) = child.w(3,k) + 1e-5;
    end
    [score0(:,:,k),Ix0(:,:,k),Iy0(:,:,k)] = shiftdt(child.score(:,:,k), child.w(1,k), child.w(2,k), child.w(3,k), child.w(4,k),child.startx(k),child.starty(k),Nx,Ny,child.step);
  end

  % At each parent location, for each parent mixture 1:L, compute best child mixture 1:K
  L  = length(parent.filterid);
  N  = Nx*Ny;
  i0 = reshape(1:N,Ny,Nx);
  [score,Iy,Ix,Ik] = deal(zeros(Ny,Nx,L));
  for l = 1:L
    b = child.b(1,l,:); % child.b \in 1xLxK, score0 \in NyxNxxK
    [score(:,:,l),I] = max(bsxfun(@plus,score0,b),[],3); % for each l, find the best mix k of child
    i = i0 + N*(I-1);
    Ix(:,:,l)    = Ix0(i);
    Iy(:,:,l)    = Iy0(i);
    Ik(:,:,l)    = I;
  end

% Backtrack through DP msgs to collect ptrs to part locations
function [box ptr] = backtrack(x,y,mix,parts,pyra)
  numx     = length(x);
  numparts = length(parts);
  
  xptr = zeros(numx,numparts);
  yptr = zeros(numx,numparts);
  mptr = zeros(numx,numparts);
  box  = zeros(numx,4,numparts);

  for k = 1:numparts,
    p   = parts(k);
    if k == 1,
      xptr(:,k) = x;
      yptr(:,k) = y;
      mptr(:,k) = mix;
    else
      % I = sub2ind(size(p.Ix),yptr(:,par),xptr(:,par),mptr(:,par));
      par = p.parent;
      [h,w,foo] = size(p.Ix);
      I   = (mptr(:,par)-1)*h*w + (xptr(:,par)-1)*h + yptr(:,par);
      xptr(:,k) = p.Ix(I);
      yptr(:,k) = p.Iy(I);
      mptr(:,k) = p.Ik(I);
    end
    scale = pyra.scale(p.level);
    x1 = (xptr(:,k) - 1 - pyra.padx)*scale+1;
    y1 = (yptr(:,k) - 1 - pyra.pady)*scale+1;
    x2 = x1 + p.sizx(mptr(:,k))*scale - 1;
    y2 = y1 + p.sizy(mptr(:,k))*scale - 1;
    box(:,:,k) = [x1 y1 x2 y2];
  end
  box = reshape(box,numx,4*numparts);
  ptr(:,:,1) = xptr;
  ptr(:,:,2) = yptr;
  ptr(:,:,3) = mptr;