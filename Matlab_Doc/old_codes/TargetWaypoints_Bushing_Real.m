function [xyzTargets, rotMatTarget, control_time, gripperforce] = TargetWaypoints_Real(demo_case)
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ���׷κ��� �ν� pick %%%%%%%%%%%%%%%%%%%%%%%%%%%%
                         %1       2       3       4   
    pick.xyzTargets =   [ 0.480   0.480   0.480   0.480  0.480;    % x [m]
                          0.200   0.200   0.200   0.300  0.200;  % y [m]
                         -0.100  -0.200  -0.200   0.100  0.100];  % z [m]  
    pick.gripperforce = [-5       2      -5      -5      -5];  %���� ���۽ÿ� �ش� �� �Ϸ���    
    pick.control_time = [ 3       3.0     0.8     1       2]; 
    pick.rotMatTarget = [ R_x(pi) R_x(pi) R_x(pi) R_x(pi)  R_x(pi)];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%% �׸��۸� ���Ա� ���� �� �������� �ν� ����%%%%%%%%%%%%%%%%%%%%%%%
                                   %1       2       3      4       
    insert_end.xyzTargets =    [ 0.470   0.470   0.470  0.470;    % x [m]
                                 0.088   0.104   0.104  0.104;    % y [m]
                                 0.100  -0.020  -0.020  0.070];  % z [m]   
    insert_end.gripperforce =  [-5      -5       3      3    ];  %���� ���۽ÿ� �ش� �� �Ϸ��� 
    insert_end.control_time =  [ 1.5     1.5     0.5    1    ]; 
    rot_i = R_x(pi-pi/8);
%     insert_end.rotMatTarget = [ R_x(pi)  rot_i   rot_i  rot_i];
    insert_end.rotMatTarget = [ R_x(pi)    rot_i   rot_i  rot_i];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% �ν� pushing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            %1       2       3       4  
    pushing.xyzTargets =   [ 0.530   0.530   0.530;    % x [m]
                            -0.100   0.200  -0.050;    % y [m]
                            -0.035  -0.035  -0.035];  % z [m]
    pushing.gripperforce = [-5      -1.5    -5 ];           
    pushing.control_time = [ 1.5     3.0     1.0 ];
    pushing.rotMatTarget = [ R_x(pi) R_x(pi) R_x(pi)];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% �ٴڿ� �ν� place %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                          %1       2          
    place.xyzTargets =   [ 0.500   0.500;    % x [m]
                          -0.110  -0.110;    % y [m]
                          -0.150  -0.020 ];  % z [m]
    place.gripperforce = [-5       2     ];           
    place.control_time = [ 2.5     1.5   ];
    place.rotMatTarget = [ R_x(pi) R_x(pi)];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    if demo_case == 1
            %%%%%%%%%%%%%%%%%%% Ư����Ż ���� pick&insert ���ȭ ���� %%%%%%%%%%%%%%%
        xyzTargets =       [pick.xyzTargets   ];
        gripperforce =     [pick.gripperforce ];           
        control_time =     [pick.control_time ];        
        rotMatTarget_Set = [pick.rotMatTarget ]; 
        for i = 1 : size(xyzTargets,2)          
            rotMatTarget{i} = rotMatTarget_Set(:,3*i-2:3*i);          
        end         
    end
end

