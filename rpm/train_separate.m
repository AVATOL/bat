function model = train_separate(model,species,kk,fix_def)
%

for c = 1:length(species)
  spe = species{c};
  name = spe.prefix;
  pos = spe.tr;
  
  pmodel = model{c};
  [pmodel.w, pmodel.wreg, pmodel.w0, pmodel.noneg] = model2vec(pmodel);
  
  fprintf('-- train_separate: species %s\n', name);
  warp = 0; debug = 0; cmpnt = 1;
  model{c} = train_inner_rpm(name,pmodel,pos,warp,debug,kk,fix_def,cmpnt);
end