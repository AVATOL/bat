function res = defvector(px,py,x,y,mix,part)
% Compute the deformation feature given parent locations, 
% child locations, and the child part

probex = ( (px-1)*part.step + part.startx(mix) );
probey = ( (py-1)*part.step + part.starty(mix) );
dx = probex - x;
dy = probey - y;
res = -[dx^2 dx dy^2 dy]';