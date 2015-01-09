function model = merge_part_models(part_models, parent, trains, params)
%

model = init_model(params);
model.parent = parent; 
model.num_parts = length(part_models);
model.len = 0;

model = add_factors(params, model, 'node', part_models);
model = add_factors(params, model, 'edge', trains);
model.w = modeltow(model);
