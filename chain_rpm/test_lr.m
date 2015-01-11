function [cl, Z, pcorr] = test_lr(net, X, y) 
% X: (nsamples,dim)
% y: (nsamples,1)

pcorr = 0;
nclass = 2;

Z = glmfwd(net, X);
[foo, cl] = max(Z');

if nargin < 2
    return
end

% recode y in one-of-nclass format
id = eye(nclass);
t = id(y,:);

ctot = sum(t);  % number of samples per class
cm = zeros(nclass); % confusion matrix

nsp = size(X,1);
for i = 1:nsp
    cm(y(i),cl(i)) = cm(y(i),cl(i)) +1;
end

pcorr = diag(cm) ./ ctot';

labels = {'presence','absence'};
for i = 1:nclass
    fprintf('%15s %5.3f\n',labels{i}, pcorr(i));
end

