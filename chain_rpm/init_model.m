function model = init_model(params)
% return model.{node,bias,edge,len,num_parts}

num_parts = params.num_parts;
%num_edges = num_parts - 1; % tree
%wdim = 1+prod(params.tsize);

model.num_parts = num_parts;
model.node(num_parts,1).w = [];
model.node(num_parts,1).i = [];
model.bias(num_parts,1).w = [];
model.bias(num_parts,1).i = [];
%model.len = num_parts*wdim ;

model.edge(num_parts,num_parts).w = [];
model.edge(num_parts,num_parts).i = [];
%model.len = model.len + num_edges*4;

model.len = 0;

