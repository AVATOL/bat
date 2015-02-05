function net = train_lr(X, y)
% X: (n_samples, dim)
% y; (n_samples, 1)

D = size(X,2);
nclass = 2;

id = eye(nclass);
t = id(y,:);

net = glm(D, nclass, 'logistic');

options = foptions;
options(1) = 1; % set to 1 to display error values during training
options(14) = 10; %  maximum number of iterations 

net = glmtrain(net, options, X, t);
