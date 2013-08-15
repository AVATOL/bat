function model = makemodel(sbin,tsize)

% size of HOG features
model.sbin = sbin;

% bias
b.w = 0;
b.i = 1;

% filter
f.w = zeros(tsize);
f.i = 1+1;

% set up one component model
c(1).biasid = 1;
c(1).defid = [];
c(1).filterid = 1;
c(1).parent = 0;
model.bias(1)    = b;
model.defs       = [];
model.filters(1) = f;
model.components{1} = c;

% initialize the rest of the model structure
model.interval = 10;
model.maxsize = tsize(1:2);
model.len = 1+prod(tsize);

