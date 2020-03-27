% ũ���Ľ� �ΰ� ������ Ȱ���� ��Ű¡ �ϴ� ���� ����
% ������� �ٽ� ��ġ����� ���ư��� ���۷��� ������ �ذ���
% �� threshold �����̳�, �� gradient�� -�϶��� ������ �� �ڿ�������� ����
% Z���� ��� ���� ������ ������ ��ġ ��Ȯ�� �� ������ ������ �� ���ڿ������� ���� ����(Z���� ��� �߷°� ���� �������� �������� �������� �ʰ� ���ִ� ��� ����)
%%
clear *;
close all;
clc

%% setting parmaeters
%controlmode = 1 : cartesian space control
%controlmode = 2 : joint pace control
controlmode = 1;

%gravity setting 1 : z axis
%gravity setting 2 : axis based on base gyro sensor
gravitysetting = 1;

% position/force control Threshold
desired_force = 14;

% holdeffect velocity Threshold
velocityThreshold = 1;

%% HEBI setting
HebiLookup.initialize();
[kin,gains,trajGen,group,cmd,grippergroup,grippercmd] = HEBI_Arm_Initialize;
group.startLog('dir','logs');
           
%% Target Waypoints          
%11:ũ���Ľ� �ΰ� ��Ű¡ (���� �ٽ� �ؾ���)
%12:ũ���Ľ� �� �� ��Ű¡ (���� �ٽ� �ؾ���)
demo_case = 11;
[xyzTargets, rotMatTarget, isgripper, gripperforce] = TargetWaypoints_Crayon(demo_case);

% Inverse Kinematics initial position
initPosition = [ 0 pi/4 pi/2 pi/4 -pi pi/2 ];  % [rad]

for i=1:length(xyzTargets(1,:))
    posTargets(i,:) = kin.getIK( 'xyz', xyzTargets(:,i), ...
                                 'SO3', rotMatTarget{i}, ...
                                 'initial', initPosition ); 
end           
% kin.getFK('endeffector', posTargets(2,:))
%% gravity direction
[gravityVec] = HEBI_Arm_gravity(gravitysetting);

%% holdeffect setting
stiffness = 10 * ones(1,kin.getNumDoF());

%% log data setting
poscmdlog = [];posfbklog = [];
Telog = [];Felog = [];deflectionlog = [];Tc_poslog = [];Fc_poslog = [];Tc_forcelog = [];Fc_forcelog = [];Tmlog = [];
ControlSwitchlog = []; Xelog = []; Velog = []; Xdlog = []; Vdlog = [];

%% trajectory & control
%%%%%%%%%%%%%%%%%%%%% go from here to initial waypoint %%%%%%%%%%%%%%%%%%%%
%control setting
fbk = group.getNextFeedback();
waypoints = [ fbk.position;
              posTargets(1,:) ];    % [rad]
time = [ 0 3];    % [sec]
trajectory = trajGen.newJointMove( waypoints, 'time', time );
t0 = fbk.time;
t = 0;
ControlSwitch = 0;
while t < trajectory.getDuration
    
    % Get feedback and update the timer
    fbk = group.getNextFeedbackFull();
    t = fbk.time - t0;
    [pos,vel,acc] = trajectory.getState(t);
    
    %get Jacobian
    J = kin.getJacobian('endeffector',fbk.position);

    %get external torque exerted on joint and endeffector
    Te = fbk.deflection'.*[130 170 70 70 70 70]';
    Fe = inv(J')*Te;             
    
    % Account for external efforts due to the gas spring
    effortOffset = [0 -7.5+2.26*(fbk.position(2) - 0.72) 0 0 0 0];
    
    gravCompEfforts = kin.getGravCompEfforts( fbk.position, gravityVec );
    dynamicCompEfforts = kin.getDynamicCompEfforts( fbk.position, ...
                                                    pos, vel, acc );
                                                
    Tm = dynamicCompEfforts + gravCompEfforts + effortOffset;
    Tc = -gains.positionKp.*(fbk.position - pos);% -gains.velocityKp.*(fbk.velocity - vel);
    
    cmd.position = [];
    cmd.velocity = [];
    cmd.effort = Tm + Tc;
    
    group.send(cmd);    
end    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%% go next waypoints %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%control setting
time = [ 0 3];    % [sec]
idlePos = fbk.position;

%initial condition
Xd = [xyzTargets(:,1);pi;0;0]';
Xe = Xd; %�̺κ��� ������ FK���� ��ǥ���� ���� �� ���� ���Ƿ� �ִ� ��. 
for i=1:size(xyzTargets,2)-1
    
    % ������� �۵����� ���� ���� target position�� �������� ������ ��� ���� ��ġ���� ���� ��ġ�� ����
    if abs(posTargets(i,2) - fbk.position(2)) > 0.1
        waypoints = [ fbk.position ;
                      posTargets(i+1,:) ];
    else        
        waypoints = [ posTargets(i,:) ;
                      posTargets(i+1,:) ];
    end
    if i == 8
        trajectory = trajGen.newJointMove( waypoints, 'time', [0 1.2]);
    else
        trajectory = trajGen.newJointMove( waypoints, 'time', time);
    end

    
        
    t0 = fbk.time;
    t = 0;    
    ControlSwitch = 0;    deflection_pre = 0;
    while t < trajectory.getDuration
        
        % Get feedback and update the timer
        fbk = group.getNextFeedbackFull();
        t = fbk.time - t0;
        [pos,vel,acc] = trajectory.getState(t);
        
        %get Jacobian
        J = kin.getJacobian('endeffector',fbk.position);
        
        %get endeffector position%velocity
        dt = 1/group.getFeedbackFrequency;
        Ve = (J * fbk.velocity')';
        Xe = Xe + Ve * dt;
        
        %get external torque exerted on joint and endeffector
        Te = fbk.deflection.*[130 170 70 70 70 70];
        Fe = (inv(J')*Te')';       
      
        % Account for external efforts due to the gas spring
        effortOffset = [0 -7.5+2.26*(fbk.position(2) - 0.72) 0 0 0 0];
%         effortOffset = [0 -7 0 0 0 0];


        gravCompEfforts = kin.getGravCompEfforts( fbk.position, gravityVec );
        dynamicCompEfforts = kin.getDynamicCompEfforts( fbk.position, ...
                                                        pos, vel, acc);
                                                    
        %get endeffector desired position%velocity
        if ControlSwitch == 1       
            Vd = Vd; % ����� �Ǵ� ���� �ٸ� ���� �׶��� ��ġ�� ����
            Xd = Xd; % ����� �Ǵ� ���� �ٸ� ���� �׶��� ��ġ�� ����
            Xd(3) = Xe(3); % ������� ��ġ����� ����ġ �ɶ� Ƣ�� ���� ������
            Vd(3) = Ve(3); % ������� ��ġ����� ����ġ �ɶ� Ƣ�� ���� ������
        else
            Jd = kin.getJacobian('endeffector',pos);
            Vd = (Jd * vel')';
            Xd = Xd + Vd * dt;
        end            
        
        %������ �۵� ����                                                       
        if ControlSwitch == 0
            if Fe(3) >= desired_force
%                 ControlSwitch = 1
            end
        end
        
        %ũ���� ��Ű¡ �� �� ��� ����
%         ePgain = [300 300 600 20 20 10];
%         eVgain = [0.1 0.1 0.1 0.1 0.1 0.1];        

%         ePgain = [300 300 450 20 20 10];
        ePgain = [300 300 400 20 20 10];
        eVgain = [0.1 0.1 0.1 0.1 0.1 0.1];        
        
        %��ġ����
        Tm = dynamicCompEfforts + gravCompEfforts + effortOffset;
        if controlmode == 1 %cartesian sapce control           
            Fc_pos = -ePgain .* (Xe - Xd) - eVgain .* (Ve - Vd); 
            if ControlSwitch == 1
                Fc_pos(3) = 0;
            end
            Tc_pos = (J' * Fc_pos')';
        else %joint space control            
            Tc_pos = -gains.positionKp.*(fbk.position - pos)  -gains.velocityKp.*(fbk.velocity - vel);
        end
        
        %������
        if ControlSwitch == 1            
            Fc_force = [0 0 0.8*(Fe(3) - desired_force) 0 0 0];
            Tc_force = (J' * Fc_force')';
        else
            Fc_force = [0 0 0 0 0 0];
            Tc_force = (J' * Fc_force')';
        end

        cmd.position = [];
        cmd.velocity = [];
        cmd.effort = Tm + Tc_pos + Tc_force;        
        group.send(cmd);   
        
        % �׸��� ����        
        if isgripper(i)  == 1
            grippercmd.position = [];
            grippercmd.velocity = [];
            grippercmd.effort = gripperforce(i+1);
        else
            grippercmd.position = [];
            grippercmd.velocity = [];
            grippercmd.effort = gripperforce(i+1);
        end
        grippergroup.send(grippercmd);  

        % data log
        poscmdlog = [poscmdlog; pos];
        posfbklog = [posfbklog; fbk.position];    
        deflectionlog = [deflectionlog;fbk.deflection];
        Telog = [Telog;Te];
        Felog = [Felog;Fe];   
        Tmlog = [Tmlog;Tm];
        Tc_poslog = [Tc_poslog;Tc_pos];
        if controlmode == 1
            Fc_poslog = [Fc_poslog;Fc_pos];
        end
        Tc_forcelog = [Tc_forcelog;Tc_force];
        Fc_forcelog = [Fc_forcelog;Fc_force];
        Xelog = [Xelog;Xe];
        Velog = [Velog;Ve];
        Xdlog = [Xdlog;Xd];
        Vdlog = [Vdlog;Vd];       
        ControlSwitchlog = [ControlSwitchlog;ControlSwitch];          
    end    
end

%% plot
% Stop logging and plot the command vs feedback pos/vel/effort
log = group.stopLog();

% HebiUtils.plotLogs( log, 'position');
% HebiUtils.plotLogs( log, 'velocity');
% HebiUtils.plotLogs( log, 'effort');

% subplot6a([0:dt:(size(Telog,1)-1)*dt],Telog,'Te')    
subplot6a([0:dt:(size(Felog,1)-1)*dt],Felog,'Fe')  

% subplot6a([0:dt:(size(Tmlog,1)-1)*dt],Tmlog,'Tm')

subplot6a([0:dt:(size(Tc_poslog,1)-1)*dt],Tc_poslog,'Tc pos') 
subplot6a([0:dt:(size(Fc_poslog,1)-1)*dt],Fc_poslog,'Fc pos') 
subplot6a([0:dt:(size(Tc_forcelog,1)-1)*dt],Tc_forcelog,'Tc force') 
subplot6a([0:dt:(size(Fc_forcelog,1)-1)*dt],Fc_forcelog,'Fc force') 

% subplot6a([0:dt:(size(poscmdlog,1)-1)*dt],posfbklog-poscmdlog,'poserror')
subplot6a([0:dt:(size(poscmdlog,1)-1)*dt],Xelog-Xdlog,'Xerror')
% subplot6a([0:dt:(size(poscmdlog,1)-1)*dt],Velog-Vdlog,'Verror')

% subplot6a([0:dt:(size(poscmdlog,1)-1)*dt],posfbklog,'posfbk')
% subplot6a([0:dt:(size(poscmdlog,1)-1)*dt],poscmdlog,'poscmd')

% subplot6a([0:dt:(size(Xelog,1)-1)*dt],Xelog,'Xe') 
% subplot6a([0:dt:(size(Velog,1)-1)*dt],Velog,'Ve') 
% subplot6a([0:dt:(size(Xdlog,1)-1)*dt],Xdlog,'Xd') 
% subplot6a([0:dt:(size(Vdlog,1)-1)*dt],Vdlog,'Vd') 

% subplot6a([0:dt:(size(deflectionlog,1)-1)*dt],deflectionlog,'defelction') 

% save("positioncontrol.mat",'poscmdlog',"posfbklog","Telog","Felog","deflectionlog","Tc_poslog","Fc_poslog","Tc_forcelog","Fc_forcelog","Tmlog","ControlSwitchlog","Xelog","Velog","Xdlog","Vdlog")
% load forcecontrol.mat


