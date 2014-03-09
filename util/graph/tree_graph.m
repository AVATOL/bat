function b = tree_graph(adj_mat)
% is adj_mat a tree graph?

b = ~any(sum(adj_mat,1) > 1);
