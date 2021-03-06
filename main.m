clear all; close all;
addpath('./utils')

% read mesh
[V,F] = load_mesh('./data/bunny.obj');
nV = size(V,1);

%% Precomputation
% ADMM rotation fitting precomputation
rotData.V = V;
rotData.F = F;
rotData.N = per_vertex_normals(V,F); % input vertex normal
rotData.L = cotmatrix(V,F); % cotangent 
rotData.VA = full(diag(massmatrix(V,F))); % vertex area

% ADMM rotation fitting parameters
rotData.lambda = 4e-1; % cubeness
rotData.rho = 1e-4;
rotData.ABSTOL = 1e-5;
rotData.RELTOL = 1e-3;
rotData.mu = 5;
rotData.tao = 2; 
rotData.maxIter_ADMM = 100;

% ARAP precomputation
ARAPData.L = cotmatrix(V,F); % cotangent 
ARAPData.preF = []; % prefactorization of L
[~,ARAPData.K] = arap_rhs(V,F,[],'Energy','spokes-and-rims');

%% Optimization
% optimization parameters
tolerance = 1e-3;
maxIter = 500;

U = V; % output vertex positions
UHis = zeros(size(V,1), size(V,2), maxIter+1);
UHis(:,:,1) = U; % output vertex history
objHis = []; % objective history

b = 1000; % pinned down vertices, we have to pin down at least one vertex
bc = U(b,:);

for iter = 1:maxIter
    
    % local step
    [RAll, objVal, rotData] = fitRotationL1(U, rotData);
    
    % save optimization info
    objHis = [objHis objVal];
    UHis(:,:,iter+1) = U; 
    
    % global step
    Rcol = reshape(permute(RAll,[3 1 2]),nV*3*3, 1);
    Bcol = ARAPData.K * Rcol;
    B = reshape(Bcol,[size(Bcol,1)/3 3]);
    UPre = U;
    [U,ARAPData.preF] = min_quad_with_fixed(ARAPData.L/2,B,b,bc,[],[],ARAPData.preF);

    % stopping criteria
    dU = sqrt(sum((U - UPre).^2,2));
    dUV = sqrt(sum((U - V).^2,2));
    reldV = max(dU) / max(dUV);
    fprintf('iter: %d, objective: %d, reldV: %d\n', [iter, objVal, reldV]);
    if reldV < tolerance
        break;
    end
end

%% visualize result
t = tsurf(F,U, 'EdgeColor', 'black');
axis equal
