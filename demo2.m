% demo2.m
addpath(genpath('.'))

rt_path = 'data/vent_small/';
nInstances = 20;
class_name = {'A', 'M2', 'N', 'S', 'T'};
target = 'M1';
sources = setdiff(class_name, target);

show_data = 1;
demo_active = 0;
save_model = 1;
model_scores = train_struct(rt_path, nInstances, target, sources, ...
    show_data, demo_active, save_model);
