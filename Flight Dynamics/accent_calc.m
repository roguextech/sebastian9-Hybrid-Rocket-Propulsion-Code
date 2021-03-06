function [t, state] = accent_calc( DTF,tend )
    %Function calculates the assent phase of the rocket
    global env;
    global log;
    state_0 = [DTF.X; DTF.Q; DTF.P; DTF.L];
    tspan = [0:tend];
    % Event function to stop at max height
    options = odeset('Events',@event_function);
    % Solve flight using ODE45
    [t, state]= ode45(@flight,tspan,state_0,options);
    % --------------------------------------------------------------------------
    %% Equations of motion discribed to be sloved in ode45
    function state_dot = flight(t,state)
        %TODO: put condition on burn data so it does not excecute after
        %burnout
        if (t>0)
            DTF.deltat = t - DTF.time;
            DTF.time = t;
            burn_data(DTF); % runs each cycle to update motor stats
        end
        X= state(1:3);
        Q= state(4:7);
        P= state(8:10);
        L= state(11:13);
        DTF.X= state(1:3);
        DTF.Q= state(4:7);
        DTF.P= state(8:10);
        DTF.L= state(11:13);
        % Rotation matrix for transforming body coord to ground coord
        Rmatrix= quat2rotm(DTF.Q');
        % Axis wrt earth coord
        YA = Rmatrix*env.YA0';
        PA = Rmatrix*env.PA0';
        RA = Rmatrix*env.RA0';
        CnXcp = DTF.CnXcp;
        Cn= CnXcp(1);
        Xcp= CnXcp(2);
        Cda = CnXcp(3); % Damping coefficient
        zeta = CnXcp(4); % Damping ratio
        Ssm = CnXcp(5); % Static stability margin
        %% ------- X Velocity-------
        Xdot=P./DTF.Mass;
        %% ------- Q Angular velocity--------- in quarternians
        invIbody = DTF.Ibody\eye(3); %inv(DTF.Ibody); inverting matrix
        omega = Rmatrix*invIbody*Rmatrix'*L;
        s = Q(1);
        v =[Q(1); Q(2); Q(3)];
        sdot = -0.5*(dot(omega,v));
        vdot = 0.5*(s*omega + cross(omega,v));
        Qdot = [sdot; vdot];
        %% -------Angle of attack-------
        % Angle between velocity vector of the CoP to the roll axis, given in the ground coord
        % To Do : windmodel in env, Model gives errors
        if(norm(X) < DTF.Rail)
            W = [0, 0, 0]';
        else
            W = env.W;
        end
        Vcm = Xdot + W;
        Xstab = Xcp- DTF.Xcm;
        omega_norm = normalize(omega); %normalized
        Xperp =Xstab*sin(acos(dot(RA,omega_norm))); % Prependicular distance between omaga and RA
        Vomega = Xperp *cross(RA,omega);
        V = Vcm + Vomega; % approxamating the velocity of the cop
        Vmag = norm(V);
        Vnorm = normalize(V);
        alpha = acos(dot(Vnorm,RA));
        DTF.alpha = alpha;
        %% ------- P Forces = rate of change of Momentums-------
        Fthrust = DTF.T*RA;
        mg = DTF.Mass*env.g;
        Fg = [0, 0, -mg]';
        % Axial Forces
        Famag = 0.5*env.rho*Vmag^2*DTF.A_ref*DTF.Cd; % To DO: make axial
        Fa = -Famag*RA;
        % Normal Forces
        Fnmag = 0.5*env.rho*Vmag^2*DTF.A_ref*Cn;
        RA_Vplane = cross(RA,Vnorm);
        Fn = Fnmag*(cross(RA,RA_Vplane));
        if (DTF.T< mg && X(3)< 0.1)
            Ftot = [0, 0, 0]';
        else
            Ftot = Fthrust + Fg + Fa + Fn;
        end
        %% ------- L Torque-------
        Trqn = Fnmag*Xstab*(RA_Vplane);
        m=diag([1, 1, 0]);
        invR = Rmatrix';
        Trq_da = -Cda*Rmatrix*m*invR*omega;
        %Tqm=(Cda1*omega)*omegaax2; rotational torque by motor
        % r_f = %TODO roll damping
        % Trmag = 0.5*env.rho*V^2*DTF.A_ref*DTF.Cld*r_f;
        % Tr = Trmag*RA;
        if(norm(X) < DTF.Rail)
            Trq = [0, 0, 0]';
            DTF.departureState(1) = norm(Xdot); % Get rail departure vel from here wrt earth
            DTF.departureState(2) = t;
        else
            Trq = Trqn+Trq_da;
        end
        %% -------Update rocket state derivatives-------
        DTF.Xdot= Xdot;
        DTF.Qdot= Qdot;
        DTF.Pdot= Ftot;
        DTF.Ldot= Trq;
        state_dot =[Xdot; Qdot; Ftot;Trq];
        %% -------Burnout time-------
        if(DTF.propM_current<0.01 && DTF.t_Burnout == 0 )
            DTF.t_Burnout = t;
        end
        %% Log Data
        logData(DTF.alpha, DTF.Cd, Cda, DTF.Xcm, DTF.Mass, Vmag, Xcp, zeta, Ssm, t);
    end
    function [value,isterminal,direction] = event_function(t,state)
        %% stops ode integration when the max height is reached
        if (t > 1 && state(10) <= 0) % Linear momentum in z direction is zero
            value = 0; % when value = 0, an event is triggered
        else
            value =1;
        end
        isterminal = 1; % terminate after the first event
        direction = 0; % get all the zeros
    end
end