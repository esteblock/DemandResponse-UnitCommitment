function UC_DR_Iglesias(Solver,Gens,Demanda,Avail,DR_Data,T,factorRE)
    #With Solver we allow Julia to solve the problem with Gurobi or CPLEX
    #Gens is the array of Generators' characteristics and restrictions:
    p_min=Gens[:p_min];
    p_max=Gens[:p_max];
    c_on=Gens[:c_on];
    c_off=Gens[:c_off];
    c_var=Gens[:c_var];
    c_ramp=Gens[:c_ramp];   
    min_on=Gens[:min_on];
    min_off=Gens[:min_off];
    type_gen=Gens[:type];
    ramp_up=Gens[:ramp_up];
    ramp_down=Gens[:ramp_down];
    v_minimo=Gens[:v_minimo]; #Minimum stored water level (for hydro reservoirs)
    v_inicial=Gens[:v_inicial]; #Initial stored water level
    zone=Gens[:zone];
    eta=Gens[:eta];   
    G=countnz(Gens[1]);#Quantity of Power Stations

    #Demanda is the baseline demand array
    Tmax =countnz(Demanda[:demanda])
    if T>Tmax
        T=Tmax
    end
    Days=convert(Int,(T/24));

    #DR_Data carries the DR Characteristics (costs)
    #alpha_r is alpha_a (adjustment)
    theta=DR_Data[:theta][1];
    alpha_c=DR_Data[:alpha_c][1];
    alpha_r=DR_Data[:alpha_r][1];
    beta_c=DR_Data[:beta_c][1];
    beta_r=DR_Data[:beta_r][1];
    
    println("T: ",T," G: ",G)

    
    #Fixed and Flexible demand.
    #In our model we always use theta=1
    D_F=Demanda[:demanda]*(1-theta)
    D_R=Demanda[:demanda]*theta

    #Set the solver
    if Solver=="Gurobi"
        uc=Model(solver=GurobiSolver(Presolve=0))
    end
    if Solver=="Cplex"
        uc=Model(solver=CplexSolver(CPX_PARAM_MEMORYEMPHASIS=1,CPX_PARAM_WORKMEM=23000,CPX_PARAM_REDUCE=1)) 
    end

    #Demand Response restrictions:
        #Load reduction:
    @variable(uc, 0 <= Rdown[t=1:T] <= D_R[t])
        #Load Increment
    @variable(uc,0<= Rup[t=1:T]<=D_R[t])


    #Power Generation: P
    @variable(uc, P[g=1:G, t=1:T] >=0)
    #Renewable energy curtailment: C
    @variable(uc, C[g=1:G, t=1:T] >=0)
    #Daily demand curtailment Rc
    @variable(uc,Rc[day=1:Days] >=0)
    #Generators' state variables
    @variable(uc,u[g=1:G, t=1:T],Bin)
    @variable(uc,ON[g=1:G, t=1:T],Bin) 
    @variable(uc,OFF[g=1:G, t=1:T],Bin) 
    #Hydro reservoirs' volume levels
    @variable(uc,V[g=1:G, t=1:T]>=v_minimo[g])

    #Costs
    @variable(uc,ONOFFCost>=0)
    @variable(uc,VarCost>=0)
    @variable(uc,CurtCost>=0)
    @variable(uc,FlexCost>=0)
    #Ramping definition and costs
    @variable(uc,CRamp[g=1:G, t=1:T]>=0)
    @variable(uc,RampCost>=0)

    #OnOff costs definition
    @constraint(uc,ONOFFCost==sum(ON[g,t]*c_on[g]+OFF[g,t]*c_off[g] for g=1:G,t=1:T))
    #Variable costs
    @constraint(uc,VarCost==sum(c_var[g]*P[g,t] for g=1:G,t=1:T))
    #Ramping costs
    @constraint(uc,RampCost==sum(CRamp[g,t] for g=1:G,t=2:T))


    #Objective function

    @objective(uc,Min,ONOFFCost+
        sum(alpha_r*(Rdown[t]-Rup[t])^2+beta_r*Rdown[t]+beta_r*Rup[t] for t=1:T)+
        sum(alpha_c*(Rc[day])^2 + beta_c*Rc[day] for day=1:Days)+
        VarCost+RampCost)

    #Daily demand curtailment definition
    for day=1:Days
        @constraint(uc,Rc[day]==sum((Rdown[t]-Rup[t]) for t=((day-1)*24+1):(day*24)))
    end


    
    ### PROBLEM CONSTRAINTS
    # # Power Balance as spot price dual variable
    @constraintref spot[1:T]
    for t = 1:T
          spot[t] = @constraint(uc, sum(P[g,t] for g=1:G)==D_F[t]+(D_R[t]-(Rdown[t]-Rup[t])))
    end
    
    # # Restrictions to Generators:
    for g in 1:G
        ## Thermal Generators
        if (type_gen[g]=="CAR")||(type_gen[g]=="DIE")||(type_gen[g]=="GNLCC")||(type_gen[g]=="GNLCA")

            #Ramping costs definition per unit
            for t in 2:T
                @constraint(uc,CRamp[g,t]>= c_ramp[g]*(P[g,t]-P[g,t-1]-ON[g,t]*p_max[g])) #rampeo subida
                @constraint(uc,CRamp[g,t]>= c_ramp[g]*(P[g,t-1]-P[g,t]-OFF[g,t]*p_max[g])) #rampeo bajada
            end            

            #Minimum Operation Times:
            #Only if min_on or min_off >1... let's start with min_on
            if min_on[g]>1
                #for t in 1:min_on[g]#
                for t in 1:min(min_on[g],T)
                   @constraint(uc, sum(ON[g,tau] for tau=1:t)<=u[g,t]) #First Restriction MOT
                end
                for t in min_on[g]+1:T
                    @constraint(uc, sum(ON[g,tau] for tau=(t-min_on[g]):t)<=u[g,t])#Second Restriction MOT
                end
            end

            # # Minimum Downtimes:
            if min_off[g]>1
                for t in 1:min(min_off[g],T)
                #for t in 1:min_off[g]
                    @constraint(uc, sum(OFF[g,tau] for tau=1:t)<=(1-u[g,t]))#First Restriction MDT
                end
                for t in min_off[g]+1:T
                   @constraint(uc, sum(OFF[g,tau] for tau=(t-min_off[g]):t)<=(1-u[g,t]))#Second Restriction MDT
                end 
            end
         # #Unit commitment restrictions:
            for t in 1:T
                @constraint(uc,P[g,t] <= p_max[g]*u[g,t]) #maximum
                @constraint(uc,P[g,t] >= p_min[g]*u[g,t]) #minimum
            end
         #  # On/Off definition
                @constraint(uc,u[g,1]==ON[g,1]-OFF[g,1])
            for t in 2:T
                #On/Off definition
                @constraint(uc,u[g,t]==(u[g,t-1]+ON[g,t]-OFF[g,t]))
            end
            ## Ramping
            if ramp_up[g]<p_max[g]
                for t in 2:T
                    @constraint(uc,P[g,t]-P[g,t-1]<=ramp_up[g])
                end
            end

            if ramp_down[g]<p_max[g]
                for t in 2:T
                    @constraint(uc,P[g,t-1]-P[g,t]<=ramp_down[g])
                end
            end            
                    
            
        end
        #Solar (FV: Fotovoltaicos, in Spanish )or Wind (EOL, Eólicos, in Spanish) Genrators
        if (type_gen[g]=="EOL")||(type_gen[g]=="FV")
            for t in 1:T
                @constraint(uc,P[g,t]<= (factorRE*p_max[g]*Avail[Symbol(zone[g])][t]))
                @constraint(uc,C[g,t] == (factorRE*p_max[g]*Avail[Symbol(zone[g])][t]-P[g,t]))
            end
        end
        
        #Run-of-the-river (PAS: Pasada, in Spanish)
        if (type_gen[g]=="PAS")
            for t in 1:T
            	@constraint(uc,P[g,t] <= p_max[g])
                @constraint(uc,P[g,t] <= (eta[g]*Avail[Symbol(zone[g])][t]))
                @constraint(uc,C[g,t] == (eta[g]*Avail[Symbol(zone[g])][t]-P[g,t]))
            end
        end

        #Hydro reservoirs (EMB: Embalses, in Spanish)
        if (type_gen[g]=="EMB")
            @constraint(uc,V[g,1]==(v_inicial[g]+Avail[Symbol(zone[g])][1]-P[g,1]/eta[g]))
            @constraint(uc,V[g,1]>=v_minimo[g])
           for t in 2:T
                @constraint(uc,V[g,t]==(V[g,t-1]+Avail[Symbol(zone[g])][t]-P[g,t]/eta[g]))
                @constraint(uc,V[g,t]>=v_minimo[g])    
            end
            @constraint(uc,V[g,T]>=v_inicial[g])
        end
        
    end

    solve(uc)
    return getvalue(P),
    getvalue(C),
    getvalue(u),
    getvalue(ON),
    getvalue(OFF),
    getvalue(ONOFFCost),
    getvalue(VarCost),
    getobjectivevalue(uc),#Total Cost
    getvalue(Rdown),
    getvalue(Rup),
    getvalue(spot),
    getvalue(Rc),
    getvalue(RampCost)
end
    
