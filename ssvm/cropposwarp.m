function [im, box] = cropposwarp(im, box)

% [newim, newbox] = croppos(im, box)
% Crop positive example to speed up latent search.

% x1 = box.xy(box.v==1,1);
% y1 = box.xy(box.v==1,2);
% x2 = box.xy(box.v==1,3);
% y2 = box.xy(box.v==1,4);
x1 = box(:,1);
y1 = box(:,2);
x2 = box(:,3);
y2 = box(:,4);
x1 = min(x1); y1 = min(y1); x2 = max(x2); y2 = max(y2);
    
% crop image around bounding box
pad = 0.5*((x2-x1+1)+(y2-y1+1));
x1 = max(1, round(x1-pad));
y1 = max(1, round(y1-pad));
x2 = min(size(im,2), round(x2+pad));
y2 = min(size(im,1), round(y2+pad));

im = im(y1:y2, x1:x2, :);
box(:,[1 3]) = box(:,[1 3]) - x1 + 1;
box(:,[2 4]) = box(:,[2 4]) - y1 + 1;
