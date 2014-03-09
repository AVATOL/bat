function model = train_interface(species,sbin,kk,kkk,fix_def,tsize)
%

if nargin < 3
  kk = 100;
  kkk = 100;
  fix_def = 1;
  tsize = [4 4 32];
end

globals;

%% config
name = '';
for i = 1:length(species)
  name = [name species{i}.prefix];
end
file = [cachedir name '.log'];
delete(file);
diary(file);

%% init model. NOTE: all part sizes should be the same by configuring point2box()
model = initmodel(species{1}.tr, sbin, tsize); % or use canonical tsize

%*** NO support for mix-parts currently

%% individual training of parts
train_parts(species, model, cachedir);

%% 1st round
cls = [name '_round1_' num2str(kk) '_' num2str(fix_def)];
try 
  load([cachedir cls]);
catch
  jointmodel = buildmodel_rpm(model,species,cachedir);
  jointmodel = train_separate(jointmodel,species,kk,fix_def);
  save([cachedir cls],'jointmodel');
end

%% 2nd round
cls = [name '_round2_' num2str(kkk) '_' num2str(fix_def)];
try 
  load([cachedir cls]);
catch
  jointmodel = train_separate(jointmodel,species,kkk,fix_def);
  save([cachedir cls],'jointmodel');
end

%% merge to RPM
model = jointmodel;