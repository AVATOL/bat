function vis_feat(w)

pad = 2;
bs = 20;

w = foldHOG(w);
scale = max(abs(w(:)));
p = HOGpicture(w, bs);
p = padarray(p, [pad pad], 0);
p = uint8(p*(255/scale));    
% border 
p(:,1:2*pad) = 128;
p(:,end-2*pad+1:end) = 128;
p(1:2*pad,:) = 128;
p(end-2*pad+1:end,:) = 128;
im = p;

imagesc(im); colormap gray; axis equal; axis off; drawnow;


%% helper functions
function f = foldHOG(w)
% f = foldHOG(w)
% Condense HOG features into one orientation histogram.
% Used for displaying a feature.

f=max(w(:,:,1:9),0)+max(w(:,:,10:18),0)+max(w(:,:,19:27),0);

function im = HOGpicture(w, bs)
% HOGpicture(w, bs)
% Make picture of positive HOG weights.

% construct a "glyph" for each orientaion
bim1 = zeros(bs, bs);
bim1(:,round(bs/2):round(bs/2)+1) = 1;
bim = zeros([size(bim1) 9]);
bim(:,:,1) = bim1;
for i = 2:9,
    bim(:,:,i) = imrotate(bim1, -(i-1)*20, 'crop');
end

% make pictures of positive weights bs adding up weighted glyphs
s = size(w);    
w(w < 0) = 0;    
im = zeros(bs*s(1), bs*s(2));
for i = 1:s(1),
    iis = (i-1)*bs+1:i*bs;
    for j = 1:s(2),
        jjs = (j-1)*bs+1:j*bs;          
        for k = 1:9,
            im(iis,jjs) = im(iis,jjs) + bim(:,:,k) * w(i,j,k);
        end
    end
end

