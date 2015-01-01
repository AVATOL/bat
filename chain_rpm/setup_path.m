% 

addpath solvers;
addpath solvers/helpers;
addpath ../visualization;
addpath ../util;

if isoctave()
  addpath ../oct;
else
  addpath ../mex;
end

cachedir = 'cache/';
if ~exist(cachedir,'dir')
  mkdir(cachedir);
end
