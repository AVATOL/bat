function train_parts(species, model, cachedir)

%globals;

for spe = species
  spe = spe{1};
  name = spe.prefix;
  numparts = spe.num_parts;
  %pmsk = spe.part_mask;
  pmap = spe.part_map;
  K = spe.num_mix;
  pos = spe.tr;
  
  fprintf('-- train_parts: species %s\n', name);
  
  % NO support for mix-parts currently
  idx = cell(1,numparts);
  for i = 1:numparts
    idx{i} = ones(length(pos),1);
  end
  
  % train part filters independently
  for p = 1:numparts
    fprintf('-- %s: %d -> %d\n', name, p, pmap(p));
    cls = [name '_part_' num2str(p) '_mix_' num2str(K(p))];
    if ~exist([cachedir cls '.mat'], 'file')
      %sneg = neg(1:min(length(neg),100));
      models = cell(1,K(p));
      for k = 1:K(p)
        spos = pos(idx{p} == k);
        for n = 1:length(spos)
          spos(n).x1 = spos(n).x1(p);
          spos(n).y1 = spos(n).y1(p);
          spos(n).x2 = spos(n).x2(p);
          spos(n).y2 = spos(n).y2(p);
        end
        %model = initmodel(spos,sbin);
        model.dag = spe.dag;
        [models{k}] = train_inner_rpm(cls,model,spos,1,0);
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
  end % numparts
end % species