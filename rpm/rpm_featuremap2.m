function phi = rpm_featuremap2(param, x, y)
% phi = detect_featuremap(param, x, y)
% computes the joint feature map phi(x,y). 
% 
% It is important that the implementation is consistent with the detect_oracle.m!
% 
% INPUT:
% param = {parts, warp, len, sbin}
% x = {feat, pyra}
% y = {bbox, level, mix}
% OUTPUT:
% phi = {bias_root, HOG_root, bias_1, HOG_1, def_1, ..., bias_P, HOG_P, def_P}

parts = param.parts;
numparts = length(parts);
len = param.len;
warp = param.warp;

phi = zeros(len,1);

% use ex from detection
if isfield(y, 'ex')
  for b = y.ex.blocks
    n  = numel(b.x);
    i1 = b.i;
    i2 = i1 + n - 1;
    is = i1:i2; % TODO: make sure indices are correct
    f  = reshape(b.x,n,1);
    phi(is) = f;
    % DEBUG
    %if length(is) == 4*4*32
    %    fprintf('start: %d, end: %d, meanvalue = %f\n', i1, i2, mean(f));
    %end
  end
  return
end

% NOTE: run warppos() before
if warp
  phi(1) = 1;
  phi(2:end) = x.feat;
  return
end

% compute feature from scratch
%mix = y.bbox(end-1);
%xy = reshape(y.bbox(1:end-2),[4,numparts]);
xy = y.bbox';

if ~isfield(y, 'level')
  y.level = ones(numparts, 1);
end

if ~isfield(y, 'mix')
  y.mix = ones(numparts, 1);
end

nodes = y.nodes;
edges = y.edges;

% root
pt = 1;
p = parts(1);
mix = y.mix(1);
scale = x.pyra.scale(y.level(1));
px = ceil((xy(1,1)-1) / scale + x.pyra.padx + 1); % TODO: use testoverlap() better?
py = ceil((xy(2,1)-1) / scale + x.pyra.pady + 1);

phi(pt) = 1;
pt = pt + 1;

f = x.pyra.feat{y.level(1)}(py:py+p.sizy(mix)-1,px:px+p.sizx(mix)-1,:);
wdim = p.sizy(mix)*p.sizx(mix)*32;
phi(pt:pt+wdim-1) = f;
pt = pt + wdim;

if nodes(1)
    phi(pt) = 0;
else
    phi(pt) = 1;
end
pt = pt + 1;

% parts
for k = 2:numparts
  p = parts(k);
  mix = y.mix(k);
  par = p.parent;
  scale = x.pyra.scale(y.level(par)); % TODO: check par and k in different layers
  ppx = ceil((xy(1,par)-1) / scale + x.pyra.padx + 1); % TODO: check use ceil or round, round seems incorrect
  ppy = ceil((xy(2,par)-1) / scale + x.pyra.pady + 1);
  scale = x.pyra.scale(y.level(k));
  px = ceil((xy(1,k)-1) / scale + x.pyra.padx + 1);
  py = ceil((xy(2,k)-1) / scale + x.pyra.pady + 1);
  % bias
  phi(pt) = 1;
  pt = pt + 1;
  % filter
  f = x.pyra.feat{y.level(k)}(py:py+p.sizy(mix)-1,px:px+p.sizx(mix)-1,:);
  wdim = p.sizy(mix)*p.sizx(mix)*32;
  phi(pt:pt+wdim-1) = f;
  pt = pt + wdim;
  % def
  fd = defvector(ppx,ppy,px,py,mix,p);
  phi(pt:pt+4-1) = fd;
  pt = pt + 4;
  % ominode
  if nodes(k)
      phi(pt) = 0;
  else
      phi(pt) = 1;
  end
  pt = pt + 1;
  % omiedge
  if edges(k-1)
      phi(pt) = 0;
  else
      phi(pt) = 1;
  end
  pt = pt + 1;
end

assert(pt - 1 == len);
