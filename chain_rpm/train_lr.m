function net = train_lr(X, y)
% X: (n_samples, dim)
% y; (n_samples, 1)

D = size(X,2);
nclass = 2;

id = eye(nclass);
t = id(y,:);

net = glm(D, nclass, 'logistic');

OPTIONS=zeros(1,18);
default_options=[0,1e-4,1e-4,1e-6,0,0,0,0,0,0,0,0,0,0,0,1e-8,0.1,0];
OPTIONS=OPTIONS+(OPTIONS==0).*default_options;
options = OPTIONS;
options(1) = 1; % set to 1 to display error values during training
options(14) = 10; %  maximum number of iterations 

net = glmtrain(net, options, X, t);
