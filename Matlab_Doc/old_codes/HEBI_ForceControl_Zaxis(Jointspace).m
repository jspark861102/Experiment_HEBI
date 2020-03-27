% Z���� (joint space) ������ ����
% Z���⸸ ������ �ϰ�, ������ ������ p���� Ȱ���� holding torque�� Ȱ��
%���������� ���̺긮�� ��/��ġ ����� �����ϳ� joint space���� ������(�۾� ���������� Ȱ���� �����)
%����� D���� Ȱ���غ� (���� �������� ����ؼ� ���� ���� ����, ū �� ����ϴ� ������ �ʹ� ŭ(���������))
%%
clear *;
close all;

%% setting parmaeters
%ctrmode 1 : ���Ϳ� position ����(�߷�,coriolis���� ��ũ ��������)
%ctrmode 2 : ���Ϳ� torque ����
ctrmode = 2;

%gravity setting 1 : z axis
%gravity setting 2 : axis based on base gyro sensor
gravitysetting = 1;

%% Target Waypoints
xyzTargets = [ 0.42   0.42   0.42;    % x [m]
               0.07   0.07   0.07;    % y [m]
              -0.20  -0.30  -0.20];  % z [m]
          
% xyzTargets = [ 0.42   0.42;    % x [m]
%                0.07   0.07;    % y [m]
%               -0.15  -0.25];  % z [m]
          
desired_deflection = 0.015;    
           
%% HEBI setting
HebiLookup.initialize();

% kin = HebiKinematics('hrdf/6-DoF_arm_w_gripper_KIMM.hrdf');
kin = setupArm('6dof_w_gripper');
gains = HebiUtils.loadGains('gains/6-DoF_arm_gains_KIMM[basic].xml');
trajGen = HebiTrajectoryGenerator();

familyName = 'Arm';%'6-DoF Arm';
moduleNames = {'Base','Shoulder','Elbow','Wrist1','Wrist2','Wrist3'};

group = HebiLookup.newGroupFromNames( familyName, moduleNames );
group.send('gains',gains);
cmd = CommandStruct();

group.startLog('dir','logs');
           
%% gravity direction
if gravitysetting == 1
        gravityVec = [0 0 -1];
elseif gravitysetting ==2
    fbk = group.getNextFeedbackFull();
    baseRotMat = HebiUtils.quat2rotMat( [ 
        fbk.orientationW(1), ...
        fbk.orientationX(1), ...
        fbk.orientationY(1), ...
        fbk.orientationZ(1) ] );
    gravityVec = -baseRotMat(3,1:3);  
end

%% trajectory & control
% rotMatTarget = R_y(pi/2);   % [3x3 SO3 Matrix]
% rotMatTarget = R_y(pi);   % [3x3 SO3 Matrix]
rotMatTarget = R_x(pi);   % [3x3 SO3 Matrix]
              
initPosition = [ 0 pi/4 pi/2 pi/4 -pi pi/2 ];  % [rad]

for i=1:length(xyzTargets(1,:))
    posTargets(i,:) = kin.getIK( 'xyz', xyzTargets(:,i), ...
                                 'SO3', rotMatTarget, ...
                                 'initial', initPosition ); 
end

fbk = group.getNextFeedback();
waypoints = [ fbk.position;
              posTargets(1,:) ];    % [rad]
timeToMove = 3;             % [sec]
time = [ 0 timeToMove ];    % [sec]
trajectory = trajGen.newJointMove( waypoints, 'time', time );

% Initialize timer
t0 = fbk.time;
t = 0;

poscmdlog = [];posfbklog = [];jointTorquelog = [];Felog = [];deflectionlog = [];

group.send(CommandStruct());
while t < trajectory.getDuration
    
    % Get feedback and update the timer
    fbk = group.getNextFeedback();
    t = fbk.time - t0;
    
    % Get new commands from the trajectory
    [pos,vel,acc] = trajectory.getState(t);
    poscmdlog = [poscmdlog; pos];
    posfbklog = [posfbklog; fbk.position];
    
    % Account for external efforts due to the gas spring
    effortOffset = [0 -7.5+2.26*(fbk.position(2) - 0.72) 0 0 0 0];
    
    gravCompEfforts = kin.getGravCompEfforts( fbk.position, gravityVec );
    dynamicCompEfforts = kin.getDynamicCompEfforts( fbk.position, ...
                                                    pos, vel, acc );
    
    if ctrmode == 1
        cmd.position = pos;
        cmd.velocity = vel;
        cmd.effort = dynamicCompEfforts + gravCompEfforts + effortOffset;
    elseif ctrmode ==2 
        cmd.position = [];
        cmd.velocity = [];
        cmd.effort = -gains.positionKp.*(fbk.position - pos) +...% -gains.velocityKp.*(fbk.velocity - vel) + ...
                dynamicCompEfforts + gravCompEfforts + effortOffset;
    end
    
    group.send(cmd);
end    

% timeToMove = 5;             % [sec]
time(1,:) = [ 0 7 ];    % [sec]
time(2,:) = [ 0 3 ];    % [sec]


velocityThreshold = 1;
stiffness = 10 * ones(1,kin.getNumDoF());
fbk = group.getNextFeedback();
idlePos = fbk.position;
stiffness = stiffness .* ones(1,group.getNumModules()); % turn into vector

group.send(CommandStruct());
for i=1:size(xyzTargets,2)-1
    
    % ������� �۵����� ���� ���� target position�� �������� ������ ��� ���� ��ġ���� ���� ��ġ�� ����
    if abs(posTargets(i,2) - fbk.position(2)) > 0.1
        waypoints = [ fbk.position ;
                  posTargets(i+1,:) ];
    else        
        waypoints = [ posTargets(i,:) ;
                      posTargets(i+1,:) ];
    end

    trajectory = trajGen.newJointMove( waypoints, 'time', time(i,:) );
%     trajectory = trajGen.newLinearMove( waypoints, 'time', time );
    
    t0 = fbk.time;
    t = 0;    
    flag = 0;    deflection_pre = 0;
    while t < trajectory.getDuration
        
        % Get feedback and update the timer
        fbk = group.getNextFeedbackFull();
        t = fbk.time - t0;
        
        %get Jacobian
        J = kin.getJacobian('endeffector',fbk.position);
        
        % deflection & joint torque & endeffector force
        deflectionlog = [deflectionlog;fbk.deflection];   
        jointTorque = fbk.deflection'.*[130 170 70 70 70 70]';
        Fe = inv(J')*jointTorque;
        jointTorquelog = [jointTorquelog;jointTorque'];
        Felog = [Felog;Fe'];    
        
        [pos,vel,acc] = trajectory.getState(t);
        poscmdlog = [poscmdlog; pos];
        posfbklog = [posfbklog; fbk.position];
        
        % Account for external efforts due to the gas spring
        effortOffset = [0 -7.5+2.26*(fbk.position(2) - 0.72) 0 0 0 0];

        gravCompEfforts = kin.getGravCompEfforts( fbk.position, gravityVec );
        dynamicCompEfforts = kin.getDynamicCompEfforts( fbk.position, ...
                                                        pos, vel, acc);
       %������ �۵� ����                                                       
       if flag == 0
            if fbk.deflection(2) >= desired_deflection
                flag = 1;
            end
       end
        
        %��ġ����
        if flag == 0
            if ctrmode == 1
                cmd.position = pos;
                cmd.velocity = vel;
                cmd.effort = dynamicCompEfforts + gravCompEfforts + effortOffset;
            elseif ctrmode == 2
                cmdeffort = -gains.positionKp.*(fbk.position - pos)  -gains.velocityKp.*(fbk.velocity - vel) + ...
                            dynamicCompEfforts + gravCompEfforts + effortOffset;
                cmd.position = [];
                cmd.velocity = [];
                cmd.effort = cmdeffort;
            end
        end
        
        %������
        if flag == 1
            cmdeffort = gravCompEfforts + effortOffset;
            
            % Find whether robot is actively moving
            isMoving = max(abs(fbk.velocity)) > velocityThreshold;
            if isMoving
                % Update idle position
                idlePos = fbk.position;
            else
                % Add efforts from virtual spring to maintain position
                driftError = idlePos - fbk.position;
                holdingEffort = driftError .* stiffness;
                holdingEffort(2) = 0;
                cmdeffort = cmdeffort + holdingEffort;
            end  
            
            cmdeffort(2) = cmdeffort(2) + 177 * (fbk.deflection(2) - desired_deflection*1.5)...
                                        + 300 * (fbk.deflection(2) - deflection_pre);
                                    
            cmd.effort = cmdeffort;
        end
        
        group.send(cmd);        
        deflection_pre = fbk.deflection(2);
    end
    
end

%% plot
% Stop logging and plot the command vs feedback pos/vel/effort
log = group.stopLog();
% HebiUtils.plotLogs( log, 'position');
% HebiUtils.plotLogs( log, 'velocity');
HebiUtils.plotLogs( log, 'effort');

figure;plot(deflectionlog(:,2),'LineWidth',1.5)
hold on
plot([0 1000],[desired_deflection desired_deflection],'--r')
title('position+force ocntrol')
legend('deflection','threshold')
ylabel('deflection(rad)')
xlabel('step')
% ylim([-0.008 0.01])
xlim([0 1000])
grid on

figure;
subplot(2,3,1)
plot(jointTorquelog(:,1))
title('jointTorque')
subplot(2,3,2)
plot(jointTorquelog(:,2))
subplot(2,3,3)
plot(jointTorquelog(:,3))
subplot(2,3,4)
plot(jointTorquelog(:,4))
subplot(2,3,5)
plot(jointTorquelog(:,5))
subplot(2,3,6)
plot(jointTorquelog(:,6))


figure;
subplot(2,3,1)
plot(Felog(:,1))
title('Endeffector Force')
subplot(2,3,2)
plot(Felog(:,2))
subplot(2,3,3)
plot(Felog(:,3))
subplot(2,3,4)
plot(Felog(:,4))
subplot(2,3,5)
plot(Felog(:,5))
subplot(2,3,6)
plot(Felog(:,6))
