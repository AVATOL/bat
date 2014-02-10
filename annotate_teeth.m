close all
addpath(genpath(pwd));

dir1 = 'data/vent_small/A/';
dir2 = 'data/vent_small/G/';
dir3 = 'data/vent_small/M2/';
dir4 = 'data/vent_small/T/';
dir5 = 'data/vent_small/M1/';
dir6 = 'data/vent_small/S/';

pname1 = {'N', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
pname2 = {'N', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
pname3 = {'N', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
pname4 = {'N', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I1', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};
pname5 = {'N', 'I1', 'C', 'P5', 'M1', 'M2', 'I1', 'C', 'P5', 'M1', 'M2'};
pname6 = {'N', 'I2', 'C', 'P4', 'P5', 'M1', 'M2', 'I2', 'C', 'P4', 'P5', 'M1', 'M2'};

% annotateParts(dir1, 'resize.png', '', pname1);
annotateParts(dir2, 'resize.png', '', pname2);
annotateParts(dir3, 'resize.png', '', pname3);
annotateParts(dir4, 'resize.png', '', pname4);
annotateParts(dir5, 'resize.png', '', pname5);
annotateParts(dir6, 'resize.png', '', pname6);