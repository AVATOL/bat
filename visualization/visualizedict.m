function visualizedict(S, sx, sy, sz, ix)

pad = 2;
bs = 20;
numparts = size(S,2);
%startpoint = zeros(numparts,2);
%startpoint(1,:) = [0 0];

%ix = 5;
iy = ceil(numparts / ix);

iux = sx*bs + pad*2;
iuy = sy*bs + pad*2;

isx = ix * iux;
isy = iy * iuy;
im = zeros(isy,isx);

for k = 0:numparts-1
    w = reshape(S(:,k+1), [sx sy sz]);
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
   
    lx = mod(k,ix) + 1;
    ly = floor(k / ix) + 1;
    
    im((ly-1)*iuy+1:ly*iuy, (lx-1)*iux+1:lx*iux) = p;
end

% plot parts   
imagesc(im); colormap gray; axis equal; axis off; drawnow;
end
