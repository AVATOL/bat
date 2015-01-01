function feat = def_feat(px,py,x,y,pady,padx,edge)
% Compute the deformation feature given parent locations, 

ax = edge.anchor(1); 
ay = edge.anchor(2); 
ds = edge.anchor(3); 

step = 2^ds;
virtpady = (step-1)*pady;
virtpadx = (step-1)*padx;
starty = ay-virtpady;
startx = ax-virtpadx;

probex = ( (px-1)*step + startx );
probey = ( (py-1)*step + starty );
dx = probex - x;
dy = probey - y;
feat = -[dx^2 dx dy^2 dy]';
