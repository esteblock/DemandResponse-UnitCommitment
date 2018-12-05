function UC_DR_Iglesias(Solver,Gens,Demanda,Avail,DR_Data,T,factorRE)
    #V22, incluyo el costo de rampeo (costo de ciclaje)
    #c_ramp_COAL=1.8;
    #c_ramp_DIE=1.8;
    #c_ramp_GNLCA=0.5;
    #c_ramp_GNLCC=0.5;
    c_ramp=Gens[:c_ramp];   
    #Centrales Format.
#num	name	type	zone	ramp_up	ramp_down	min_on	min_off	p_min	p_max	c_on	c_off	c_var	eta	v_inicial	v_minim
    
#1       2        3      4       5         6         7        8       9      10      11      12       13     14     15        16            
    Tmax =countnz(Demanda[:demanda])
    if T>Tmax
        T=Tmax
    end
    Days=convert(Int,(T/24));
# # DR Characteristics
    theta=DR_Data[:theta][1];
    alpha_c=DR_Data[:alpha_c][1];
    alpha_r=DR_Data[:alpha_r][1];
    beta_c=DR_Data[:beta_c][1];
    beta_r=DR_Data[:beta_r][1];
# # Generators Characteristics
    G=countnz(Gens[1]);#Quantity of Power Stations
    println("T: ",T," G: ",G)
    #Groups=counter(Centrales[:type])
    #G_T=Groups["TER"]
    #G_EOL=Groups["EOL"]
    #G_FV=Groups["FV"]
    #G_EMB=Groups["EMB"]
    #G_PAS=Groups["PAS"]
    p_min=Gens[:p_min];
    #P_max=Centrales[8];
    p_max=Gens[:p_max];
    #c_on=Centrales[9];
    c_on=Gens[:c_on];
    #c_off=Centrales[10];
    c_off=Gens[:c_off];
    #c_v=Centrales[11];
    c_var=Gens[:c_var];
    #TminOn=Centrales[3];
    min_on=Gens[:min_on];
    min_off=Gens[:min_off];
    type_gen=Gens[:type];
    ramp_up=Gens[:ramp_up];
    ramp_down=Gens[:ramp_down];
    v_minimo=Gens[:v_minimo];
    v_inicial=Gens[:v_inicial];
    zone=Gens[:zone];
    eta=Gens[:eta];   
# # Fixed Demand
    D_F=Demanda[:demanda]*(1-theta)
    D_R=Demanda[:demanda]*theta
    #D_Index=Demanda[:index]
#    alpha_c=DRInfo[1];
#    beta_c=DRInfo[2];
#    alpha_r=DRInfo[3];
#    beta_r=DRInfo[4];
    if Solver=="Gurobi"
        uc=Model(solver=GurobiSolver(Presolve=0))
        #setsolver(uc, GurobiSolver(Presolve=0))
    end
    if Solver=="Cplex"
        uc=Model(solver=CplexSolver(CPX_PARAM_MEMORYEMPHASIS=1,CPX_PARAM_WORKMEM=23000,CPX_PARAM_REDUCE=1)) 
    end
    #uc=Model(solver=CbcSolver()) 
    #Demand Response (load reduction(>0)/increment(<0))
        #Load reduction
    @variable(uc, 0 <= Rdown[t=1:T] <= D_R[t]) #In each time is constained by the original demand
        #Load Increment
    @variable(uc,0<= Rup[t=1:T]<=D_R[t])
        #Power Generation
    @variable(uc, P[g=1:G, t=1:T] >=0)
    @variable(uc, C[g=1:G, t=1:T] >=0) #renewable energy curtailment
    @variable(uc,Rc[day=1:Days] >=0)
    #@variable(uc, A[g=1:G, t=1:T] >=0) #curtailment
        #Unit Commitment
    @variable(uc,u[g=1:G, t=1:T],Bin)

            #Volume
    @variable(uc,V[g=1:G, t=1:T]>=v_minimo[g])
        #ON OFF
    @variable(uc,ON[g=1:G, t=1:T],Bin) 
    @variable(uc,OFF[g=1:G, t=1:T],Bin) 
    @variable(uc,ONOFFCost>=0)
    @variable(uc,VarCost>=0)
    @variable(uc,CurtCost>=0)
    @variable(uc,FlexCost>=0)


    @variable(uc,CRamp[g=1:G, t=1:T]>=0)
    @variable(uc,RampCost>=0)

    #@variable(uc,DRCost>=0)
        #Objective Function
    @objective(uc,Min,ONOFFCost+
        sum(alpha_r*(Rdown[t]-Rup[t])^2+beta_r*Rdown[t]+beta_r*Rup[t] for t=1:T)+
        sum(alpha_c*(Rc[day])^2 + beta_c*Rc[day] for day=1:Days)+
        VarCost+RampCost)
        #FlexCost+#alpha_c*(sum((Rdown[t]-Rup[t]) for t=1:T)^2)+
        #CurtCost)#beta_c*(sum(sum( (Rdown[t]-Rup[t]) for t=((day-1)*24+1):(day*24)) for day=1:convert(Int,(T/24))))+#beta_c*(sum((Rdown[t]-Rup[t]) for t=1:T))+
        #sum(beta_r*Rdown[t]+beta_r*Rup[t] for t=1:T)   #alpha_r*((Rdown[t]-Rup[t])^2)+
    #)
    #@objective(uc,Min,sum(c_var[g]*P[g,t] for g=1:G,t=1:T))
# # ON OFF Cost

    #@constraint(uc,FlexCost==sum(alpha_r*(Rdown[t]-Rup[t])^2+beta_r*Rdown[t]+beta_r*Rup[t] for t=1:T))# ==sum(beta_c*Rc[day]for day=1:Days))
    #@constraint(uc,CurtCost==sum(alpha_c*(Rc[day])^2 + beta_c*Rc[day] for day=1:Days))# ==sum(beta_c*Rc[day]for day=1:Days))

    ##Demand curtailment definition (per day)
    for day=1:Days
        #@constraint(uc,Rc[day]==sum((Rdown[t]-Rup[t]) for t=t=((day-1)*24+1):(day*24)))
        @constraint(uc,Rc[day]==sum((Rdown[t]-Rup[t]) for t=((day-1)*24+1):(day*24)))
    end


    @constraint(uc,ONOFFCost==sum(ON[g,t]*c_on[g]+OFF[g,t]*c_off[g] for g=1:G,t=1:T))
    @constraint(uc,VarCost==sum(c_var[g]*P[g,t] for g=1:G,t=1:T))
    @constraint(uc,RampCost==sum(CRamp[g,t] for g=1:G,t=2:T))

    #@constraint(uc,DRCost==(
    #        alpha_c*sum(Rdown[t]-Rup[t] for t=1:T)^2+
    #        beta_c*sum((Rdown[t]-Rup[t]) for t=1:T)+
    #        sum(
    #            alpha_r*(Rdown[t]-Rup[t])^2+
    #            beta_r*Rdown[t]+beta_r*Rup[t] for t=1:T)
    #        ))
# # Power Balance as spot price
    @constraintref spot[1:T]
    for t = 1:T
          spot[t] = @constraint(uc, sum(P[g,t] for g=1:G)==D_F[t]+(D_R[t]-(Rdown[t]-Rup[t])))
    end
    
    # # Restrictions to Generators:
    for g in 1:G
        ## Thermal Generators
        if (type_gen[g]=="CAR")||(type_gen[g]=="DIE")||(type_gen[g]=="GNLCC")||(type_gen[g]=="GNLCA")

            #Deifnicion del rampeo.
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
                #Ramping Restrictions
                #if (p_max[g]-ramp_up[g])>0
                    #@constraint(uc,P[g,t]-P[g,t-1]<=ramp_up[g])
                    #@constraint(uc,P[g,t-1]-P[g,t]<=ramp_down[g]) 
                #end               
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
                #for t in 1:min_off[g]
                    
            
        end
        #Solar or Wind Genrators
        if (type_gen[g]=="EOL")||(type_gen[g]=="FV")
#		println(g)
#		println(Symbol(zone[g]))
            for t in 1:T
#		println(t)
                #@constraint(uc,P[g,t]<= (p_max[g]*(Avail_FV_EOL[Symbol(zone[g])][D_Index[t]])))
                @constraint(uc,P[g,t]<= (factorRE*p_max[g]*Avail[Symbol(zone[g])][t]))
                #@constraint(uc,C[g,t] == ((p_max[g]*(Avail_FV_EOL[Symbol(zone[g])][D_Index[t]]))-P[g,t]))#*u[g,t]
                @constraint(uc,C[g,t] == (factorRE*p_max[g]*Avail[Symbol(zone[g])][t]-P[g,t]))
            end
        end
        
        if (type_gen[g]=="PAS")
            for t in 1:T
            	@constraint(uc,P[g,t] <= p_max[g])
                #@constraint(uc,P[g,t] <= eta[g]*Avail_HIDRO[Symbol(zone[g])][t])
                @constraint(uc,P[g,t] <= (eta[g]*Avail[Symbol(zone[g])][t]))
                #@constraint(uc,C[g,t] == ((eta[g]*Avail_HIDRO[Symbol(zone[g])][t])-P[g,t]))
                @constraint(uc,C[g,t] == (eta[g]*Avail[Symbol(zone[g])][t]-P[g,t]))
                #@constraint(uc,A[g,t] == (eta[g]*Avail[Symbol(zone[g])][t]))
            end
        end
        
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
    getvalue(P),
    getvalue(Rc),
    getvalue(RampCost)
end
    
