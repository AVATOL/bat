function model = trainmodel_ssvm(name,pos,K,pa,sbin)

globals;

file = [cachedir name '.log'];
delete(file);
diary(file);

%% initialization
cls = [name '_cluster_' num2str(K')'];
try
  load([cachedir cls]);
catch
  model = initmodel(pos,sbin);
  def = data_def(pos,model);
  idx = clusterparts(def,K,pa); % each part in each example has a cluster label
  save([cachedir cls],'def','idx');
end

%% train part filters independently
for p = 1:length(pa)
  cls = [name '_part_' num2str(p) '_mix_' num2str(K(p))];
%   try
%     load([cachedir cls]);
%   catch
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
      [models{k},progress] = train_inner(cls,model,spos,sneg,1);
    end
    %model = mergemodels(models); % merge mixtures
    %save([cachedir cls],'model');
%   end
end

return

%% build tree structure, determine anchor positions
cls = [name '_final1_' num2str(K')'];
try
  load([cachedir cls]);
catch
  model = buildmodel(name,model,def,idx,K,pa); % combine parts
  for p = 1:length(pa)
		for n = 1:length(pos)
			pos(n).mix(p) = idx{p}(n);
		end
	end
  model = train(cls,model,pos,neg,0,1);
  save([cachedir cls],'model');
end

%% final round
cls = [name '_final_' num2str(K')'];
try
  load([cachedir cls]);
catch
  if isfield(pos,'mix')
    pos = rmfield(pos,'mix');
  end
  model = train(cls,model,pos,neg,0,1);
  save([cachedir cls],'model');
end
