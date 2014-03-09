function model = trainmodel_rpm(name,pos,K,dag,sbin,kk,kkk,fix_def)
% dag is an adjacent matrix representing a tree

if ~tree_graph(dag)
  disp('model structure has to be a tree!\n');
  model = {};
  return
end

if nargin < 6
  kk = 100;
  kkk = 100;
  fix_def = 0;
end

globals;

name = [name '_RPM']; % extended name
file = [cachedir name '.log'];
delete(file);
diary(file);

numparts = length(pos(1).x1);
numpos = length(pos);

%% initialization
cls = [name '_cluster_' num2str(K')'];
try
  load([cachedir cls]);
catch
  model = initmodel(pos,sbin);
  def = data_def(pos,model);
  %idx = clusterparts(def,K,pa); % each part in each example has a cluster label
  % in RPM, no need to use mixture of parts, so all idx = 1
  idx = cell(1,numparts);
  for i = 1:numparts
    idx{i} = ones(numpos,1);
  end
  save([cachedir cls],'def','idx');
end

%% train part filters independently
for p = 1:numparts
  cls = [name '_part_' num2str(p) '_mix_' num2str(K(p))];
  try
    load([cachedir cls]);
  catch
    %sneg = neg(1:min(length(neg),100));
    sneg = [];
    models = cell(1,K(p));
    for k = 1:K(p)
      spos = pos(idx{p} == k);
      for n = 1:length(spos)
        spos(n).x1 = spos(n).x1(p);
        spos(n).y1 = spos(n).y1(p);
        spos(n).x2 = spos(n).x2(p);
        spos(n).y2 = spos(n).y2(p);
      end
      model = initmodel(spos,sbin);
      [models{k},progress] = train_inner(cls,model,spos,sneg,1,0);
    end
    % DEBUG code
    %visualizemodel(models{1})
    %norm(models{1}.w,2)
    %im = imread(pos(8).im);
    %[boxes] = detect_fast(im, models{1}, 0);
    %boxes = nms(boxes,0.3);
    %showboxes(im,boxes(1,:),{'g'})
    %pause;
    
    model = mergemodels(models); % merge mixtures
    save([cachedir cls],'model');
  end
end

%% build tree structure, determine anchor positions
cls = [name '_final1_' num2str(K')' '_' num2str(kk) '_' num2str(kkk) '_' num2str(fix_def)];
try
  load([cachedir cls]);
catch
  model = buildmodel_rpm(name,model,def,idx,K,dag); % combine parts
  [model.w, model.wreg, model.w0, model.noneg] = model2vec(model);
  for p = 1:numparts
		for n = 1:length(pos)
			pos(n).mix(p) = idx{p}(n);
		end
	end
  model = train_inner_rpm(cls,model,pos,[],0,kk,fix_def);
  save([cachedir cls],'model');
  % DEBUG code
%   visualizemodel(model)
%   visualizeskeleton(model)
%   im = imread(pos(8).im);
%   [boxes] = detect_fast(im, model, 0);
%   boxes = nms(boxes,0.3);
%   showboxes(im,boxes(1,:),{'g','g','g','g','g','g','g','g','g','g','g','g','g'})
end

%% final round
cls = [name '_final_' num2str(K')' '_' num2str(kk) '_' num2str(kkk) '_' num2str(fix_def)];
try
  load([cachedir cls]);
catch
  if isfield(pos,'mix')
    pos = rmfield(pos,'mix');
  end
  model = train_inner(cls,model,pos,[],0,kkk,fix_def);
  save([cachedir cls],'model');
end
