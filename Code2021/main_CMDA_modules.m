% EFFECT OF NON-KEPLERIAN MOID EVOLUTION 
% ON PRELIMINARY KEYHOLE ANALYSES
%
% Continuing...
%
% SOLUTION OF A PLANETARY ENCOUNTER: PDC 2021
% 7th IAA Planetary Defense Conference 2021
clc
clear
close all
format shortG

filename = 'main_CMDA_modules.m';
filepath = matlab.desktop.editor.getActiveFilename;
currPath = filepath(1:(end-length(filename)));
cd(currPath)
addpath(genpath(pwd))

%% ===== Description ===== 
% Original scripts: in old code folder
%  =======================

%% Script steps [TO UPDATE??] 
% 1. Read heliocentric elements (spice file) - date close to the encounter
% 2. Modify for circular Earth and adjust NEO orbit for encounter still happening
% 3. Switch to geocentric Keplerian elements and find time of perigeetp
% 4. Coordinates of the modified target plane(ξp,ζp,vp)
% 5. Compute the corresponding target plane pre-encounter coordinates (input for Öpik).(ξ,η,ζ)
% 6. Use Öpik theory to compute post-encounter coordinates
% 7. Convert to Heliocentric: Use Öpik theory formulae

%% 0. Initialization
% 1. Read heliocentric elements
cspice_furnsh( 'SPICEfiles/naif0012.tls.pc' )
cspice_furnsh( 'SPICEfiles/gm_de431.tpc' )
cspice_furnsh( 'SPICEfiles/pck00010.tpc' )
% cspice_furnsh( 'SPICEfiles/de431_part-1.bsp' )
% cspice_furnsh( 'SPICEfiles/de431_part-2.bsp' )
dir_local_de431 = 'C:\Users\Oscar\Documents\Spice-Kernels\';
cspice_furnsh( [dir_local_de431 'de431_part-1.bsp'] )
cspice_furnsh( [dir_local_de431 'de431_part-2.bsp'] )

% 2021 PDC
cspice_furnsh( 'SPICEfiles/2021_PDC-s11-merged-DE431.bsp' )
ast_id= '-937014';
epoch = '2021 October 10 TDB';
et = cspice_str2et( epoch );


cons.AU  = cspice_convrt(1, 'AU', 'KM');
cons.GMs = cspice_bodvrd( 'SUN', 'GM', 10 );
cons.GMe = cspice_bodvrd( '399', 'GM', 1 );
cons.Re  = 6378.140;

cons.yr  = 365.25 * 24 * 3600 ;
cons.Day = 3600*24; 

state_eat = cspice_spkezr( '399', et, 'ECLIPJ2000', 'NONE', '10' );
kep_eat = cspice_oscelt( state_eat, et, cons.GMs );
sma_eat = kep_eat(1)/(1-kep_eat(2));

state_ast = cspice_spkezr( ast_id, et, 'ECLIPJ2000', 'NONE', '10' );
kep_ast = cspice_oscelt( state_ast, et, cons.GMs );
sma_ast = kep_ast(1)/(1-kep_ast(2));


% 2. Modify elements for encounter with simpler Earth model
% Make Earth Circular-Ecliptic -----
kep_eat(2:3) = 0;
cons.yr = 2*pi/sqrt(cons.GMs/kep_eat(1)^3);

% Modify NEO to try to make dCA smaller ----
kep_ast(3) = kep_ast(3)+.0;     % Increase inclination
kep_ast(5) = kep_ast(5)+.06;    % Adjust arg of perihelion to low MOID
kep_ast(6) = kep_ast(6)-0.0111; % Adjust timing for very close flyby

t0 = et ;
state_ast = cspice_conics(kep_ast, t0);
state_eat = cspice_conics(kep_eat, t0);

% 3. Switch to geocentric and find time periapses
% Planetocentric frame definition (Valsecchi 2003):
% Y: Direction of motion of the planet;
% X: Sun on negative -X;
% Z: Completes
state_ast_O = HillRot(state_eat, state_ast);
kep_ast_O   = cspice_oscelt( state_ast_O, t0, cons.GMe );

% Find periapsis time
MA_per = 0;

a_ast_O = kep_ast_O(1)/(1 - kep_ast_O(2));
n_ast_O = sqrt( -cons.GMe/a_ast_O(1)^3 );
dt_per  = (MA_per - kep_ast_O(6))/n_ast_O; dt_per_day = dt_per/86400


% 4. Using ephemeris at date of perigee, obtain MTP coordinates
state_ast = cspice_conics(kep_ast, t0 + dt_per);
state_eat = cspice_conics(kep_eat, t0 + dt_per);
DU = norm( state_eat(1:3) );
TU = sqrt(DU^3/cons.GMs);
cons.AU = DU;

ap    = kep_eat(1)/(1-kep_eat(2))/DU ;
longp = mod( kep_eat(4)+kep_eat(5)+kep_eat(6), 2*pi ) ; % In general sense should be longitude

state_ast_per = HillRot(state_eat, state_ast);
r_ast_O = state_ast_per(1:3);
v_ast_O = state_ast_per(4:6);

% Coordinates at MTP - Perigee
b_p   = norm( r_ast_O );
V     = norm( v_ast_O );
theta_p = acos( v_ast_O(2)/V );
phi_p   = atan2( v_ast_O(1), v_ast_O(3) );
 
cp = cos(phi_p);   sp = sin(phi_p);
ct = cos(theta_p); st = sin(theta_p);
auxR = [cp 0 -sp;st*sp ct st*cp;ct*sp -st ct*cp];

xi_p   = r_ast_O(1)*cp - r_ast_O(3)*sp;
eta_p  = r_ast_O(1)*st*sp + r_ast_O(2)*ct + r_ast_O(3)*st*cp;
zeta_p = r_ast_O(1)*ct*sp - r_ast_O(2)*st + r_ast_O(3)*ct*cp; 


% 5. From MTP to TP
% Asymptotic velocity: Energy conservation
GME = cons.GMe;
U = sqrt( V*V - 2*GME/b_p );

U_nd = U/(DU/TU);
m = cons.GMe/cons.GMs;

% Rescaling b-plane coordinates: Angular momentum conservation
b    = (V/U)*b_p  ;
xi   = (V/U)*xi_p ;
zeta = (V/U)*zeta_p ;
 
% Rotation of velocity vector
hgamma = atan( cons.GMe/(b*U*U) );
hv     = cross( r_ast_O, v_ast_O );
DCM    = PRV_2_DCM( -hgamma, hv/norm(hv) );
UVec   = (U/V)*DCM*v_ast_O;
theta  = acos(UVec(2)/U);
phi    = atan2(UVec(1),UVec(3));

cp = cos(phi);   sp = sin(phi);
ct = cos(theta); st = sin(theta);
auxR = [cp 0 -sp;st*sp ct st*cp;ct*sp -st ct*cp];


%% 1. Compute Circles

% xi_nd   = xi/DU;
% zeta_nd = zeta/DU;
% b_nd = sqrt(xi_nd^2 + zeta_nd^2);
b_nd = b/DU;
c_nd = (cons.GMe/cons.GMs)/U_nd^2;

b2 = b_nd*b_nd;
c2 = c_nd*c_nd;
U2 = U_nd*U_nd;
% aux1 = (b2+c2)*(1-U2);
% aux2 = -2*U_nd*( (b2-c2)*ct + 2*c_nd*zeta_nd*st );

a_pre  = 1/(1-U2-2*U_nd*ct);
% a_post = (b2 + c2)/(aux1 + aux2);

kmax = 20;
hmax = 50;

i = 0;
circ = [];
for k=1:kmax
    for h=1:hmax
        
        i = i+1 ;
        a0p(i) = (k/h)^(2/3);
        if sum( find(a0p(i) == a0p(1:i-1)) ); continue; end
        
        ct0p = ( 1-U2-ap/a0p(i) )/2/U_nd ;
        if abs(ct0p) > 1; continue; end
        st0p = sqrt(1 - ct0p^2);
        
        % Cirle center location and radius
        D = (c_nd*st)/(ct0p - ct);
        R = abs( c_nd*st0p/(ct0p - ct) );
        
%         % Skip if doesn't intersect the (0,Rstar) circle
        % Does not make sense becaues we don't design maneuvers
        % However, if we don't include a filter, the keyhole search
        % explodes for the very small circles
%         Rstar = 1*cons.Re/DU;
%         if ( (abs(D)<abs(R-Rstar)) || (abs(D)>(R+Rstar)) ); continue; end
        
        circ = [circ; k h D*DU R*DU];
        
    end
end


% Plot Valsecchi Circles
plot_valsecchi_circles(2,circ,cons,U,kmax,xi,zeta); % first input, number of figure

%% 2. General Keyholes computation
% Section dependencies: scripts in 'keyholes'
[circles,kh_good_sec] = keyhole_computation(3,circ,cons,U,DU,U_nd,theta,phi);

%% 3. Keyhole selection: First paper figures
% Pick flyby from the keyholes and generate ICs

% Manually select k
tf = 20;

for i=1%:66
    
ic = kh_good_sec(i) ;
ic = 31;

k = circles(ic,1);
h = circles(ic,2);
D = circles(ic,3)/cons.Re;
R = circles(ic,4)/cons.Re;

fprintf('Keyhole number %g\n',ic)

[kh_up_xi,kh_up_zeta,kh_down_xi,kh_down_zeta] = ...
    two_keyholes(k, h, D, R, U_nd, theta, phi, m,0,DU);

% Plot selected keyhole
figure(4)
cc = [1 0 0];
sc = cons.Re/DU;

plot(kh_down_xi(:,1)/sc,kh_down_zeta(:,1)/sc,kh_down_xi(:,2)/sc,kh_down_zeta(:,2)/sc,...
    'Color',cc);
plot(kh_up_xi(:,1)/sc,kh_up_zeta(:,1)/sc,kh_up_xi(:,2)/sc,kh_up_zeta(:,2)/sc,...
    'Color',cc);

if sign(D) > 0
    
% 1. Find a point close to xi=0 (arbitrary choice)
[~,ik] = min( abs(kh_up_xi) );
xi0   = kh_up_xi(ik(1));
zeta0 = kh_up_zeta(ik(1));

% % 2. Find the first point of the keyhole arc (arbirary as well)
% ik = find( ~isnan(kh_up_xi),1, 'first' ); 
% xi0   = kh_up_xi(ik);
% zeta0 = kh_up_zeta(ik);

else

[~,ik] = min( abs(kh_down_xi) );
xi0   = kh_down_xi(ik(1));
zeta0 = kh_down_zeta(ik(1));
    
% % 2. Find the first point of the keyhole arc (arbirary as well)
% ik = find( ~isnan(kh_down_xi), 1 ); 
% xi0   = kh_down_xi(ik);
% zeta0 = kh_down_zeta(ik);

end

% Choose a point outside of the keyhole
% theta_pick = 30 *pi/180;
% xi0    = R*cos(theta_pick)*sc;
% zeta0  = (D + R*sin(theta_pick))*sc;

auxR = [cp 0 -sp;st*sp ct st*cp;ct*sp -st ct*cp];
r0   = auxR'*[xi0; 0; zeta0];

plot(xi0/sc, zeta0/sc,'rd','MarkerSize',8)

% 6. Solving the encounter with Opik formulae
% h = 0; % Number of revolutions until next encounter: only used for zeta2

% Using keyhole point selected: xi0, zeta0
[zeta2,theta1,phi1,xi1,zeta1,r_b_post,v_b_post] = opik_next(U_nd,theta,phi,xi0,zeta0,t0,h,m);

% 7. Heliocentric orbit elements from post-encounter coordinates (Opik formulae)
longp = mod( kep_eat(4)+kep_eat(5)+kep_eat(6), 2*pi ) ; % In general sense should be longitude
longp = atan2( state_eat(2),state_eat(1) );
kep_opik_post = opik_bplane_2_oe( theta1,phi1,zeta1,xi1,U_nd,phi,longp,ap )';

kep_opik_post(1) = kep_opik_post(1)*(1-kep_opik_post(2))*DU ; 
% 'opik_bplane_2_oe.m' function returns sma in first element

kep_opik_post(6) = TA_2_MA(kep_opik_post(6),kep_opik_post(2));
% 'opik_bplane_2_oe.m' function returns true anomaly 6th element

kep_opik_post(7:8) = [t0 + dt_per;
                        cons.GMs];
% Include GM of the central body and epoch

% 8. Plotting: distance over time with heliocentric elements

% Post-encounter constant elements distance
tv1 = ((-0.1:.001:tf) + 0) *cons.yr;
et0 = t0 + dt_per;

d_pe = zeros(length(tv1),1);
for i=1:length(tv1)
    xa   = cspice_conics(kep_opik_post, et0 + tv1(i) );
    xe   = cspice_conics(kep_eat,       et0 + tv1(i) );
    d_pe(i) = norm(xe(1:3) - xa(1:3)); 
end

% Initial condition
kepE_sma = kep_eat';
kepE_sma(1) = kep_eat(1)/(1-kep_eat(2));

kep0 = kep_opik_post;
kep0_sma = kep_opik_post';
kep0_sma(1) = kep0(1)/(1-kep0(2));
MOID0 = MOID_SDG_win( kep0_sma([1 2 4 3 5]), kepE_sma([1 2 4 3 5]) );
% MOID0 = ComputeMOID_mex_MAC(K2S(kep0_sma,cons.AU),K2S(kepE_sma,cons.AU));

% Numerical Integration of point
eti = et0 + 30*86400 ; % Initial ephemeris time for integration
X0  = cspice_conics(kep_opik_post, eti );
tv  = ( 0:0.001:tf )*cons.yr;

GMvec = cons.GMs;
for i=2:9
    GMvec(i)          = cspice_bodvrd( [num2str(i-1) ], 'GM', 1);
    state_planet      = cspice_spkezr( [num2str(i-1) ],  eti, 'ECLIPJ2000', 'NONE', '10' );
    kep_planet(:,i-1) = cspice_oscelt( state_planet, eti, cons.GMs );
end
kep_planet(:,3) = kep_eat ;
GMvec(3) = cons.GMe;

cons_ode.t0        = eti ;
cons_ode.GM_vec    = GMvec ; % 1st element is Sun
cons_ode.IC_planet = kep_planet ; % 1 column per planet

tol = 1e-13;
options=odeset('RelTol',tol,'AbsTol',ones(1,6)*tol);
[t,X]=ode113(@(t,X) NBP_propagator(t,X,cons_ode),tv,X0,options);

% Postprocessing
d_nbp   = zeros(length(tv),1);
kep_nbp = zeros(length(tv),8);
MOIDnbp = zeros(length(tv),1);

for i = 1:length(tv)
    kep0_nbp     = cspice_oscelt( X(i,:)', eti+tv(i), cons.GMs );
    kep_nbp(i,:) = kep0_nbp;
    kep_nbp(i,1) = kep0_nbp(1)/(1-kep0_nbp(2));
   
    MOIDnbp(i) = MOID_ORCCA_win( K2S(kepE_sma,cons.AU), K2S(kep_nbp(i,:),cons.AU) ) *cons.AU;
%     MOIDnbp(i) = ComputeMOID_mex_MAC( K2S(kep_nbp(i,:),cons.AU), K2S(kepE_sma,cons.AU) )*cons.AU;
    % Compute distance to Earth
    xe   = cspice_conics(kep_eat, eti+tv(i) );
    d_nbp(i) = norm(xe(1:3) - X(i,1:3)'); % From 4bp integration
end


% Secular Propagation
% Secular Model: Lagrange-Laplace
kepJ_sma = kep_planet(:,5);
kepJ_sma(1) = kepJ_sma(1)/(1-kepJ_sma(2));

cons_sec.OEp = kepJ_sma';
cons_sec.GMp = GMvec(6);
cons_sec.GMs = GMvec(1);

secular_model_LL = secular_model_10BP_s2(kep0_sma, cons_sec, 1);

kep_LL_t = zeros(length(tv),6);
kept = kep0_sma;
d_ll = zeros(length(tv),1);
MOIDsec = d_ll;

for i = 1:length(tv)
    
    [~, kep_LL_t(i,:)] = drifted_oe_s2( secular_model_LL, tv(i), kep0_sma, kepJ_sma' );
    kept(2:6) = kep_LL_t(i,2:6); 
    kept(1)   = kep0_sma(1)*(1-kep_LL_t(i,2));
    
    xa   = cspice_conics(kept',    eti + tv(i) );
    xe   = cspice_conics(kep_eat,  eti + tv(i) );
    d_ll(i) = norm(xe(1:3) - xa(1:3)); 
    
    MOIDsec(i) = MOID_SDG_win( kep_LL_t(i,[1 2 4 3 5]), kepE_sma([1 2 4 3 5]) );
%     MOIDsec(i) = ComputeMOID_mex_MAC( K2S(kep_LL_t(i,:),cons.AU), K2S(kepE_sma,cons.AU) )*cons.AU;
    
end



xt = (tv + eti - et0)/cons.yr ;

% Distance(t) Plot
plot_distancevstime(6,cons,xt,tv1,d_pe,d_nbp,d_ll)

% MOID(t) Plot
plot_moidvstime(5,cons,tv1,xt,MOID0,MOIDnbp,MOIDsec)


end


%% 4. MOIDIFIED Keyholes Computation
% % Section dependencies: scripts in 'keyholes'
% RE_au = cons.Re/DU;
% 
% m  = cons.GMe/cons.GMs ;
% circles = circ;
% 
% F = figure(7);
% hold on
% 
% sc = cons.Re/DU;
% nr = size(circles,1);
% kh_good_sec = [];
% 
% % longitude for MOID computation inside
% longp = atan2(state_eat(2),state_eat(1));
% 
% % Initial condition
% kepE_sma = kep_eat';
% kepE_sma(1) = kep_eat(1)/(1-kep_eat(2));
% 
% et0 = t0 + dt_per;
% eti = et0 + 30*86400 ; % Initial ephemeris time for integration
% 
% % Secular Propagation
% kep_planet = NaN(8,8);
% GMvec = cons.GMs;
% for i = 2:9
%     GMvec(i)          = cspice_bodvrd( num2str(i-1), 'GM', 1);
%     state_planet      = cspice_spkezr( num2str(i-1),  eti, 'ECLIPJ2000', 'NONE', '10' );
%     kep_planet(:,i-1) = cspice_oscelt( state_planet, eti, cons.GMs );
% end
% kep_planet(:,3) = kep_eat ;
% GMvec(3) = cons.GMe;
% 
% % Secular Model: Lagrange-Laplace
% kepJ_sma = kep_planet(:,5);
% kepJ_sma(1) = kepJ_sma(1)/(1-kepJ_sma(2));
% 
% cons_sec.OEp = kepJ_sma';
% cons_sec.GMp = GMvec(6);
% cons_sec.GMs = GMvec(1);
% 
% % Numerical Model Inputs
% cons_ode.t0        = eti ;
% cons_ode.GM_vec    = GMvec ; % 1st element is Sun
% cons_ode.IC_planet = kep_planet ; % 1 column per planet
% 
% co = winter(22);
% focus_factor = sqrt(1 + 2*cons.GMe/(cons.Re*U^2));
% 
% kh_good_sec = [];
% kh_good_num = [];
% 
% for i=1:nr
%     
%     % New circles
%     k = circles(i,1);
%     h = circles(i,2);
%     D = circles(i,3)/cons.Re;    
%     R = circles(i,4)/cons.Re;    
% 
%     %-------------------------------------------
%     % Compute secular keyholes
%     [kh_up_xi,kh_up_zeta,kh_down_xi,kh_down_zeta] = ...
%         two_keyholes_dxi(k, h, D, R, U_nd, theta, phi, m,0,DU, 2,-1,longp,ap,cons,kepE_sma,cons_sec);
% 
%     if sum(~isnan(kh_up_xi(:)))
%         fprintf('Secular Keyhole %g found!\n',i)
%     end
%     
%     subplot(1,2,1)
%     hold on
%     cc = co(k,:);    
% %     cc = [0 1 1];
% %     cc = [1 0 0];
%     plot(kh_down_xi(:,1)/sc,kh_down_zeta(:,1)/sc,kh_down_xi(:,2)/sc,kh_down_zeta(:,2)/sc,...
%         'Color',cc,'LineWidth',1);
%     pl = plot(kh_up_xi(:,1)/sc,kh_up_zeta(:,1)/sc,kh_up_xi(:,2)/sc,kh_up_zeta(:,2)/sc,...
%          'Color',cc,'LineWidth',1);
%     
%     drawnow 
%     % Register keyholes with solutions
% %     arcexist = sum(~isnan(kh_up_xi)) + sum(~isnan(kh_down_xi));
%     R1 = sqrt(sum(kh_down_xi.^2 + kh_down_zeta.^2,2));
%     R2 = sqrt(sum(kh_up_xi.^2 + kh_up_zeta.^2,2));
%     arcexist = sum( (R1-RE_au*focus_factor)>0 ) + sum( (R2-RE_au*focus_factor)>0 );
%     
%     arcexist = sum( kh_up_zeta > 2*RE_au*focus_factor );
% %     arcexist = sum( kh_down_zeta < -1.6*RE_au );
%     
%     if arcexist
%         kh_good_sec = [kh_good_sec; i];
%         fprintf('Keyhole num %g exists\n',i)
%     end
%     
%     if length(kh_good_sec) == 1
%         h_list(2) = pl(1);
%     end
%     
%     %-------------------------------------------
%     % Compute Numerical keyholes
%     [kh_up_xi,kh_up_zeta,kh_down_xi,kh_down_zeta] = ...
%         two_keyholes_dxi(k, h, D, R, U_nd, theta, phi, m,0,DU, 3,-1,longp,ap,cons,kepE_sma,cons_ode);
% 
%     if sum(~isnan(kh_up_xi(:)))
%         fprintf('Numeric Keyhole %g found!\n',i)
%     end
%     
%     subplot(1,2,2)
%     hold on
%     cc = co(k,:);    
% %     cc = [0 1 1];
% %     cc = [1 0 0];
%     plot(kh_down_xi(:,1)/sc,kh_down_zeta(:,1)/sc,kh_down_xi(:,2)/sc,kh_down_zeta(:,2)/sc,...
%         'Color',cc,'LineWidth',1);
%     pl = plot(kh_up_xi(:,1)/sc,kh_up_zeta(:,1)/sc,kh_up_xi(:,2)/sc,kh_up_zeta(:,2)/sc,...
%          'Color',cc,'LineWidth',1);
%     
%     drawnow 
%     % Register keyholes with solutions
% %     arcexist = sum(~isnan(kh_up_xi)) + sum(~isnan(kh_down_xi));
%     R1 = sqrt(sum(kh_down_xi.^2 + kh_down_zeta.^2,2));
%     R2 = sqrt(sum(kh_up_xi.^2 + kh_up_zeta.^2,2));
%     arcexist = sum( (R1-RE_au*focus_factor)>0 ) + sum( (R2-RE_au*focus_factor)>0 );
%     
%     arcexist = sum( kh_up_zeta > 2*RE_au*focus_factor );
% %     arcexist = sum( kh_down_zeta < -1.6*RE_au );
%     
%     if arcexist
%         kh_good_num = [kh_good_num; i];
%         fprintf('Keyhole num %g exists\n',i)
%     end
%     
%     if length(kh_good_num) == 1
%         h_list(2) = pl(1);
%     end
%     
%     
% end
% 
% %-------------------------------------------
% subplot(1,2,1)
% colormap(co);
% fill(RE_focussed*cos(thv), RE_focussed*sin(thv),'white');
% plot(RE_focussed*cos(thv), RE_focussed*sin(thv),'k');
% plot(cos(thv), sin(thv),'k--');
% 
% % legend(h_list,{'post-enc','sec-LL'})
% 
% grid on
% axis equal
% caxis([1 20])
% cb = colorbar;
% cb.Label.String = 'k';
% axis([-1 1 -1 1]*5)
% xlabel('\xi (R_\oplus)');
% ylabel('\zeta (R_\oplus)');
% 
% %-------------------------------------------
% subplot(1,2,2)
% colormap(co);
% fill(RE_focussed*cos(thv), RE_focussed*sin(thv),'white');
% plot(RE_focussed*cos(thv), RE_focussed*sin(thv),'k');
% plot(cos(thv), sin(thv),'k--');
% 
% % legend(h_list,{'post-enc','sec-LL'})
% 
% grid on
% axis equal
% caxis([1 20])
% cb = colorbar;
% cb.Label.String = 'k';
% axis([-1 1 -1 1]*5)
% xlabel('\xi (R_\oplus)');
% ylabel('\zeta (R_\oplus)');


%% 5. Show variation in MOID in neighboring B-plane points


% Manually select k
tf = 20;

ic = 59;

k = circles(ic,1);
h = circles(ic,2);
D = circles(ic,3)/cons.Re;
R = circles(ic,4)/cons.Re;

fprintf('Keyhole number %g\n',ic)

[kh_up_xi,kh_up_zeta,kh_down_xi,kh_down_zeta] = ...
    two_keyholes(k, h, D, R, U_nd, theta, phi, m,0,DU);

% Plot selected keyhole
figure(3)
cc = [1 0 0];
sc = cons.Re/DU;

plot(kh_down_xi(:,1)/sc,kh_down_zeta(:,1)/sc,kh_down_xi(:,2)/sc,kh_down_zeta(:,2)/sc,...
    'Color',cc);
plot(kh_up_xi(:,1)/sc,kh_up_zeta(:,1)/sc,kh_up_xi(:,2)/sc,kh_up_zeta(:,2)/sc,...
    'Color',cc);

ikv = 45:5:55 ;
plot(kh_down_xi(ikv,1)/sc,kh_down_zeta(ikv,1)/sc,'gd','MarkerSize',8);

for ik = 45:5:55

% if sign(D) > 0
    
%     % 1. Find a point close to xi=0 (arbitrary choice)
%     [~,ik] = min( abs(kh_up_xi) );
%     xi0   = kh_up_xi(ik(1));
%     zeta0 = kh_up_zeta(ik(1));
%     
%     ik = ik + 2
%     
    % % 2. Find the first point of the keyhole arc (arbirary as well)
    % ik = find( ~isnan(kh_up_xi),1, 'first' );
    % xi0   = kh_up_xi(ik);
    % zeta0 = kh_up_zeta(ik);
    
% else
    
%     [~,ik] = min( abs(kh_down_xi) );
    xi0   = kh_down_xi(ik(1));
    zeta0 = kh_down_zeta(ik(1));
    
    % % 2. Find the first point of the keyhole arc (arbirary as well)
    % ik = find( ~isnan(kh_down_xi), 1 );
    % xi0   = kh_down_xi(ik);
    % zeta0 = kh_down_zeta(ik);
    
% end

% Choose a point outside of the keyhole
% theta_pick = 30 *pi/180;
% xi0    = R*cos(theta_pick)*sc;
% zeta0  = (D + R*sin(theta_pick))*sc;

auxR = [cp 0 -sp;st*sp ct st*cp;ct*sp -st ct*cp];
r0   = auxR'*[xi0; 0; zeta0];

% plot(xi0/sc, zeta0/sc,'rd','MarkerSize',8)

% 6. Solving the encounter with Opik formulae
% h = 0; % Number of revolutions until next encounter: only used for zeta2

% Using keyhole point selected: xi0, zeta0
[zeta2,theta1,phi1,xi1,zeta1,r_b_post,v_b_post] = opik_next(U_nd,theta,phi,xi0,zeta0,t0,h,m);

% 7. Heliocentric orbit elements from post-encounter coordinates (Opik formulae)
longp = mod( kep_eat(4)+kep_eat(5)+kep_eat(6), 2*pi ) ; % In general sense should be longitude
longp = atan2( state_eat(2),state_eat(1) );
kep_opik_post = opik_bplane_2_oe( theta1,phi1,zeta1,xi1,U_nd,phi,longp,ap )';

kep_opik_post(1) = kep_opik_post(1)*(1-kep_opik_post(2))*DU ;
% 'opik_bplane_2_oe.m' function returns sma in first element

kep_opik_post(6) = TA_2_MA(kep_opik_post(6),kep_opik_post(2));
% 'opik_bplane_2_oe.m' function returns true anomaly 6th element

kep_opik_post(7:8) = [t0 + dt_per;
    cons.GMs];
% Include GM of the central body and epoch

% 8. Plotting: distance over time with heliocentric elements

% Post-encounter constant elements distance
tv1 = ((-0.1:.001:tf) + 0) *cons.yr;
et0 = t0 + dt_per;

d_pe = zeros(length(tv1),1);
for i=1:length(tv1)
    xa   = cspice_conics(kep_opik_post, et0 + tv1(i) );
    xe   = cspice_conics(kep_eat,       et0 + tv1(i) );
    d_pe(i) = norm(xe(1:3) - xa(1:3));
end

% Initial condition
kepE_sma = kep_eat';
kepE_sma(1) = kep_eat(1)/(1-kep_eat(2));

kep0 = kep_opik_post;
kep0_sma = kep_opik_post';
kep0_sma(1) = kep0(1)/(1-kep0(2));
MOID0 = MOID_SDG_win( kep0_sma([1 2 4 3 5]), kepE_sma([1 2 4 3 5]) );
% MOID0 = ComputeMOID_mex_MAC(K2S(kep0_sma,cons.AU),K2S(kepE_sma,cons.AU));


% % Secular Propagation
% % Secular Model: Lagrange-Laplace
% kepJ_sma = kep_planet(:,5);
% kepJ_sma(1) = kepJ_sma(1)/(1-kepJ_sma(2));
% 
% cons_sec.OEp = kepJ_sma';
% cons_sec.GMp = GMvec(6);
% cons_sec.GMs = GMvec(1);
% 
% secular_model_LL = secular_model_10BP_s2(kep0_sma, cons_sec, 1);
% 
% tv  = ( 0:0.001:tf )*cons.yr;
% kep_LL_t = zeros(length(tv),6);
% kept = kep0_sma;
% d_ll = zeros(length(tv),1);
% MOIDsec = d_ll;
% 
% for i = 1:length(tv)
%     
%     [~, kep_LL_t(i,:)] = drifted_oe_s2( secular_model_LL, tv(i), kep0_sma, kepJ_sma' );
%     kept(2:6) = kep_LL_t(i,2:6);
%     kept(1)   = kep0_sma(1)*(1-kep_LL_t(i,2));
%     
%     xa   = cspice_conics(kept',    eti + tv(i) );
%     xe   = cspice_conics(kep_eat,  eti + tv(i) );
%     d_ll(i) = norm(xe(1:3) - xa(1:3));
%     
%     MOIDsec(i) = MOID_SDG_win( kep_LL_t(i,[1 2 4 3 5]), kepE_sma([1 2 4 3 5]) );
% %     MOIDsec(i) = ComputeMOID_mex_MAC( K2S(kep_LL_t(i,:),cons.AU), K2S(kepE_sma,cons.AU) )*cons.AU;
%     
% end

% Numerical Integration of point
eti = et0 + 30*86400 ; % Initial ephemeris time for integration
X0  = cspice_conics(kep_opik_post, eti );
tv  = ( 0:0.001:tf )*cons.yr;

GMvec = cons.GMs;
for i=2:9
    GMvec(i)          = cspice_bodvrd( [num2str(i-1) ], 'GM', 1);
    state_planet      = cspice_spkezr( [num2str(i-1) ],  eti, 'ECLIPJ2000', 'NONE', '10' );
    kep_planet(:,i-1) = cspice_oscelt( state_planet, eti, cons.GMs );
end
kep_planet(:,3) = kep_eat ;
GMvec(3) = cons.GMe;

cons_ode.t0        = eti ;
cons_ode.GM_vec    = GMvec ; % 1st element is Sun
cons_ode.IC_planet = kep_planet ; % 1 column per planet

tol = 1e-13;
options=odeset('RelTol',tol,'AbsTol',ones(1,6)*tol);
[t,X]=ode113(@(t,X) NBP_propagator(t,X,cons_ode),tv,X0,options);

% Postprocessing
d_nbp   = zeros(length(tv),1);
kep_nbp = zeros(length(tv),8);
MOIDnbp = zeros(length(tv),1);

for i = 1:length(tv)
    kep0_nbp     = cspice_oscelt( X(i,:)', eti+tv(i), cons.GMs );
    kep_nbp(i,:) = kep0_nbp;
    kep_nbp(i,1) = kep0_nbp(1)/(1-kep0_nbp(2));
   
    MOIDnbp(i) = MOID_ORCCA_win( K2S(kepE_sma,cons.AU), K2S(kep_nbp(i,:),cons.AU) ) *cons.AU;
%     MOIDnbp(i) = ComputeMOID_mex_MAC( K2S(kep_nbp(i,:),cons.AU), K2S(kepE_sma,cons.AU) )*cons.AU;
    % Compute distance to Earth
    xe   = cspice_conics(kep_eat, eti+tv(i) );
    d_nbp(i) = norm(xe(1:3) - X(i,1:3)'); % From 4bp integration
end


xt = (tv + eti - et0)/cons.yr ;

% Distance(t) Plot
plot_distancevstime(60,cons,xt,tv,d_ll,d_ll,d_ll)

% MOID(t) Plot
plot_moidvstime(51,cons,tv,xt,MOID0,MOIDnbp,MOIDnbp)



end






