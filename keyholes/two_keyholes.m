function [kh_up_xi,kh_up_zeta,kh_down_xi,kh_down_zeta] = two_keyholes(k,h,D,R,U,theta,phi,m,t0,DU)
%% COMPUTE KEYHOLES FOR A GIVEN RESONANCE

% Convert to dimensionless units (au, but here we use the real distance of
% the Earth at the instant of close encounter)
RE_km = 6378.140;
% DU = 152003856.97586098;
RE_au = RE_km/DU;
D_au = D*RE_au;
R_au = R*RE_au;

%% The following part should be included in a loop for all -b_Earth < xi < b_Earth

c = m/U^2;
bEarth_au = RE_au*sqrt(1 + 2*c/RE_au);
% bEarth_au = RE_au;

% Get xi, zeta for the previous ranges of alpha
nkh = 100;
[xi_up,zeta_up] = res_circle(linspace(0,pi,nkh),D_au,R_au);
[xi_down,zeta_down] = res_circle(linspace(-pi,0,nkh),D_au,R_au);

% For each of these values, compute the keyhole width.

% Keyhole - bottom
zeta_edges = zeros(nkh,2);
xi_edges = zeros(nkh,2);
for i = 1:nkh
    
    xi = xi_down(i);
    zeta = zeta_down(i);
    
    % Check if xi1 <= b_Earth
    [~,~,~,xi1,~] = opik_next(U,theta,phi,xi,zeta,t0,h,m);
    if (abs(xi1) > bEarth_au)
        zeta_edges(i,:) = NaN;
        xi_edges(i,:)   = NaN;
        continue
    end
    xi2 = xi1;
    
    % Assign tentative dzeta1, dzeta2
    dz1 = 1E-6; dz2 = 1E-6;
    zetapp1 = zeta - dz1;
    zetapp2 = zeta + dz2;
    
    % Find the value of zeta leading to a direct impact
    try
        [zeta0,~] = fzero(@(zeta) opik_next(U,theta,phi,xi,zeta,t0,h,m),[zetapp1,zetapp2]);
    catch
        %disp(['fzero error at i =',i]);
        zeta_edges(i,:) = NaN;
        xi_edges(i,:)   = NaN;
        continue
    end
    
    % Compute keyhole edges
    zeta2_edges = [sqrt(bEarth_au^2 - xi2^2), -sqrt(bEarth_au^2 - xi2^2)];
    
    [~,theta1,phi1,xi1,zeta1] = opik_next(U,theta,phi,xi,zeta0,t0,h,m);
    dz2dz = dzeta2dzeta(U,theta,phi,xi,zeta0,m,h,theta1,phi1,xi1,zeta1);
    zeta_edges(i,:) = zeta0 + zeta2_edges/dz2dz;
    xi_edges(i,:) = [xi,xi];

end
kh_down_xi = xi_edges;
kh_down_zeta = zeta_edges;

% Keyhole - top
zeta_edges = zeros(nkh,2);
xi_edges = zeros(nkh,2);
for i = 1:nkh
    
    xi = xi_up(i);
    zeta = zeta_up(i);
    
    % Check if xi1 <= b_Earth
    [~,~,~,xi1,~] = opik_next(U,theta,phi,xi,zeta,t0,h,m);
    if (abs(xi1) > bEarth_au)
        zeta_edges(i,:) = NaN;
        xi_edges(i,:)   = NaN;
        continue
    end
    xi2 = xi1;
    
    % Assign tentative dzeta1, dzeta2
    dz1 = 1E-6; dz2 = 1E-6;
    zetapp1 = zeta - dz1;
    zetapp2 = zeta + dz2;
    
    % Find the value of zeta leading to a direct impact
    try
        [zeta0,~] = fzero(@(zeta) opik_next(U,theta,phi,xi,zeta,t0,h,m),[zetapp1,zetapp2]);
    catch
        %disp(['fzero error at i =',i]);
        zeta_edges(i,:) = NaN;
        xi_edges(i,:)   = NaN;
        continue
    end
    
    % Compute keyhole edges
    zeta2_edges = [sqrt(bEarth_au^2 - xi2^2), -sqrt(bEarth_au^2 - xi2^2)];
    
    [~,theta1,phi1,xi1,zeta1] = opik_next(U,theta,phi,xi,zeta0,t0,h,m);
    dz2dz = dzeta2dzeta(U,theta,phi,xi,zeta0,m,h,theta1,phi1,xi1,zeta1);
    zeta_edges(i,:) = zeta0 + zeta2_edges/dz2dz;
    xi_edges(i,:) = [xi,xi];

end
kh_up_xi = xi_edges;
kh_up_zeta = zeta_edges;

end
