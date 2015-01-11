% 

addpath solvers;
addpath solvers/helpers;
addpath ../visualization;
addpath ../util;
addpath ../external/netlab3_3;
run('../external/vlfeat-0.9.16/toolbox/vl_setup')

if isoctave()
  addpath ../oct;
else
  addpath ../mex;
end

cachedir = 'cache/';
if ~exist(cachedir,'dir')
  mkdir(cachedir);
end
