clear   
clc 
close all
% ref the paper The Probabilistic Data Association Filter
gridxMin = 0;
gridxMax = 500;
gridyMin = 0;
gridyMax = 500;
mag_min = 2;
mag_max = 2;
angle_min = 0;
angle_max = 2*pi;
p = 4;
m = 2;
T = 40;

R = 2* eye(m,m);
H = [1 0 0 0; 0 1 0 0];
Rinv = inv(R);
meanc = [0;0];
Pg =.99;
lambda = 1;
lambdaf = lambda/500/500;
Phi = [1,0,1,0;  0,1,0,1;   0,0,1,0;  0,0,0,1 ];
Q = diag([5, 5, 1 , 1]); 
P = diag([10, 10, 1 , 1]);
Pinv = inv(P);
Nt = 4; % number of target

disp('Generating Ground Truth Tracks...');
xa = cell(Nt,1);
j = 1;

while j <= Nt
    flag_restart = 0;
    
    %% initial ground truth position
    speed = mag_min+(mag_max-mag_min)*rand;
    direction = angle_min+(angle_max-angle_min)*rand;
    x = gridxMin + (gridxMax-gridxMin) * rand;
    y = gridyMin + (gridyMax-gridyMin) * rand;
    xa{j} = [x ; y ; speed*cos(direction) ; speed*sin(direction)  ];
    
    for t = 1:T
        %% generate ground truth tracks
        if t>1
            xa{j}(:,t) = Phi*xa{j}(:,t-1)+mvnrnd(zeros(p,1),Q)';
            
            % keep iterating only if within the bounding box
            if xa{j}(1,t)> 500 || xa{j}(1,t) < 0 || xa{j}(2,t) > 500 || xa{j}(2,t) < 0
                flag_restart = 1;
                break;
            end
        end
    end %timestep t
    
    if flag_restart
        continue;
    elseif norm( xa{j}(1:2,1) - xa{j}(1:2,T) ) < 200 %discard small tracks
        continue;
    else
        j = j + 1;
    end
end
disp('Generating Observations...');
[ zt,zIdt,zCountt ] = observeWithClutter( lambda,Nt,xa,H,R,T );

% init
for i = 1 : Nt
    a(i).x_ = xa{i}(:,1);
    a(i).P_ = P;
end
FOV = [0 500;0 500];
for t = 1 : T 
t
    z = zt{t};
    for j = 1 : Nt
        beta0 = 1;
        S = R * H * a(j).P_*H';
        Pd = findPd(H*a(j).x_,S,FOV);
        % compute the b_
        b_ = 2 * pi * lambdaf * sqrt(det(S)) * (1 - Pd*Pg)/Pd;
        y = zeros(m,1);
        Ptilde = zeros(m,m);
        if zCountt{t} > 0
            sum_s = 0;
            s = zeros(zCountt{t},1);
            for n = 1 : zCountt{t}
                ztilde = z(:,n) - H * a(j).x_;
                s(n) = exp(-ztilde'/S * ztilde/2);
                if s(n) < 0.0001
                    s(n) = 0;
                end
                sum_s = sum_s + s(n);
            end
            % compute the beta
            beta = zeros(zCountt{t},1);
            vk = zeros(2,1);
            for n = 1 : zCountt{t}
                innov = z(:,n) - H * a(j).x_;
                beta(n) = s(n)/(b_ + sum_s);
                vk = vk + beta(n) * innov;
                Ptilde = Ptilde +  beta(n) * innov * innov';
            end
            beta0 = b_/(b_ + sum_s);
            K = a(j).P_ * H' * inv(S);
            a(j).x(:,t) = a(j).x_ + K * vk;
            Pc = (eye(p) - K * H) * a(j).P_;
            Pp = K * (Ptilde - vk*vk') * K';
            a(j).P = beta0 * a(j).P_ + (1 - beta0)*Pc + Pp;
        else
            a(j).P = a(j).P_;
            a(j).x(:,t) = a(j).x_;
        end
    end

% predict
for j = 1 : Nt
    a(j).P_ = Phi * a(j).P * Phi' + Q;
    a(j).x_ = Phi * a(j).x(:,t);
end
end

 figure
 hold on
   for j = 1:Nt
     plot(xa{j}(1,1:T),xa{j}(2,1:T),'g','LineWidth',2);
     plot(a(j).x(1,1:T),a(j).x(2,1:T),'r','LineWidth',1);
   end 
 