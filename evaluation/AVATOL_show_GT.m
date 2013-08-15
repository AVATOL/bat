function AVATOL_show_GT(file, dir, pa, colorset)
% AVATOL_show_GT('AClass_eval.mat','/scratch/working/AVATOL/datasets/Ventral_View/Artibeus/',[0 1 1 3 4 5 6 1 8 9 10 11],{'g','g','r','r','r','r','r','b','b','b','b','b'})
if nargin < 2
    %name = 'NClass';
    dir = '/scratch/working/AVATOL/datasets/Ventral_View/Desmodus/';
    %file = 'DClass_eval.mat';
    pa = [0 1 1 3 4 5 6 7 1 9 10 11 12 13];
    colorset = {'g','g','r','r','b','b'};
end

load(file);
BB1 = cat(2,allBoxes{:});
TT1 = cat(2,allTests{:});

% show data
testGT = pointtobox(TT1,pa,1,1);
for i=1:length(TT1)
    dummy = splitstring(TT1(i).im, '/');
    imPath = [dir,dummy{end}];
    im = imread(imPath);
    testB = [testGT(i).x1;testGT(i).y1;testGT(i).x2;testGT(i).y2];
    testB = reshape(testB,[4*length(pa),1])';
    showboxes(im,testB,colorset);
    pause;
end

end

% dir1 = '/scratch/working/AVATOL/datasets/Ventral_View/Artibeus/';
% dir2 = '/scratch/working/AVATOL/datasets/Ventral_View/Desmodus/';
% dir3 = '/scratch/working/AVATOL/datasets/Ventral_View/Glossophaga/';
% dir4 = '/scratch/working/AVATOL/datasets/Ventral_View/Molossus/';
% dir5 = '/scratch/working/AVATOL/datasets/Ventral_View/Mormoops/';
% dir6 = '/scratch/working/AVATOL/datasets/Ventral_View/Noctilio/';
% dir7 = '/scratch/working/AVATOL/datasets/Ventral_View/Saccopteryx/';
% dir8 = '/scratch/working/AVATOL/datasets/Ventral_View/Trachops/';
% 
% pa1 = [0 1 1 3 4 5 6 1 8 9 10 11];
% colorset1 = {'g','g','r','r','r','r','r','b','b','b','b','b'};
% 
% pa2 = [0 1 1 3 1 5];
% colorset2 = {'g','g','r','r','b','b'};
% 
% pa3 = [0 1 1 3 4 5 6 7 1 9 10 11 12 13];
% colorset3 = {'g','g','r','r','r','r','r','r','b','b','b','b','b','b'};
% 
% pa4 = [0 1 1 3 4 5 6 1 8 9 10 11];
% colorset4 = {'g','g','r','r','r','r','r','b','b','b','b','b'};
% 
% pa5 = [0 1 1 3 4 5 6 7 1 9 10 11 12 13];
% colorset5 = {'g','g','r','r','r','r','r','r','b','b','b','b','b','b'};
% 
% pa6 = [0 1 1 3 4 5 6 7 8 1 10 11 12 13 14 15];
% colorset6 = {'g','g','r','r','r','r','r','r','r','b','b','b','b','b','b','b'};
% 
% pa7 = [0 1 2 3 4 5 6 1 8 9 10 11 12];
% colorset7 = {'g','r','r','r','r','r','r','b','b','b','b','b','b'};
% 
% pa8 = [0 1 1 3 4 5 6 7 1 9 10 11 12 13];
% colorset8 = {'g','g','r','r','r','r','r','r','b','b','b','b','b','b'};
