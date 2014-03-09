function unimodel = merge_dags(species,jointmodel,model,sid)
% NOTE: biasid and filterid may have multiple, current strategy is using
% the first one. Later will come up with something better.

if nargin < 4
  sid = [];
end

% build universe DAG
[sizy,sizx] = deal(0);
for i = 1:length(species)
  [sizyy,sizxx] = size(species{i}.dag);
  sizy = max(sizy,sizyy);
  sizx = max(sizx,sizxx);
end
assert(sizy == sizx);
dag = zeros(sizy,sizx);
for i = 1:length(species)
  pmap = species{i}.part_map;
  dagg = jointmodel{i}.dag;
  for r = 1:size(dagg,1)
    for c = 1:size(dagg,2)
      dag(pmap(r),pmap(c)) = dag(pmap(r),pmap(c)) + dagg(r,c);
    end
  end
end

alter = dag > 1;
dag = dag > 0;

% init unimodel
unimodel = model;
unimodel.dag = dag;
unimodel.alter = alter;

unimodel.bias    = struct('w',{},'i',{});
unimodel.filters = struct('w',{},'i',{});
unimodel.defs    = struct('w',{},'i',{},'anchor',{});
unimodel.components{1} = struct('biasid',{},'filterid',{},'defid',{},'parent',{});

% parent and defid initial
for c = 1:size(dag,2)
    parents = find(dag(:,c) == 1);
    %unimodel.components{1}(c).parent = [unimodel.components{1}(c).parent parents];
    unimodel.components{1}(c).parent = parents';
    unimodel.components{1}(c).defid = zeros(size(parents'));
end

% part_map of sid
smap = species{sid}.part_map;

biasBase = 0; filBase = 0; defBase = 0;
for m = 1:length(jointmodel)
  pmap = species{m}.part_map;
  parts = jointmodel{m}.components{1};
  uparts = unimodel.components{1};
  
  if sid == m
    rang = pmap;
  else
    rang = setdiff(pmap,smap);
  end

  % biasid, filterid only use sid's
  for j = 1:length(rang) % i is index in uparts, j is index in parts
    i = rang(j);
    p = parts(j);
    uparts(i).biasid = [uparts(i).biasid p.biasid+biasBase];
    uparts(i).filterid = [uparts(i).filterid p.filterid+filBase];
  end
    
  % defid use all, cause defid is indexed by child of that edge
  for j = 1:length(pmap)
    i = pmap(j);
    p = parts(j);
    if p.parent == 0
      continue
    end
    
    par = pmap(p.parent); % par has same index order as defid
    dind = (par == uparts(i).parent); % to see which defid to be updated
    assert(sum(dind) == 1);
    
    if uparts(i).defid(dind) == 0 || m == sid
      uparts(i).defid(dind) = p.defid+defBase;
    end
  end
  % update uparts
  unimodel.components{1} = uparts;
  
  % concatenate bias, filters and defs
  unimodel.bias = [unimodel.bias jointmodel{m}.bias];
  unimodel.filters = [unimodel.filters jointmodel{m}.filters];
  unimodel.defs = [unimodel.defs jointmodel{m}.defs];
  
  % cumulate index
  biasBase = biasBase + length(jointmodel{m}.bias);
  filBase = filBase + length(jointmodel{m}.filters);
  defBase = defBase + length(jointmodel{m}.defs);
end