#Editted for constrained model

oadaLikelihood_byEvent <- function(parVect, nbdadata){
 
if(is.character(nbdadata)){
	
		totalLikelihood <- NULL;
			
		for(i in 1:length(nbdadata)){
			subdata <- eval(as.name(nbdadata[i]));
			totalLikelihood <- rbind(totalLikelihood,oadaLikelihood(parVect= parVect, nbdadata=subdata));
			}
					
		return(totalLikelihood);
					
}else{

	#Define required function
	sumWithoutNA <- function(x) sum(na.omit(x))

	#calculate the number of each type of parameter
	noSParam <- dim(nbdadata@stMetric)[2] #s parameters
	noILVasoc<- dim(nbdadata@asocILVdata)[2] #ILV effects on asocial learning
	noILVint<- dim(nbdadata@intILVdata)[2] #ILV effects on interation (social learning)
	noILVmulti<- dim(nbdadata@multiILVdata)[2] #ILV multiplicative model effects
	
	if(nbdadata@asoc_ilv[1]=="ILVabsent") noILVasoc<-0
	if(nbdadata@int_ilv[1]=="ILVabsent") noILVint<-0
  if(nbdadata@multi_ilv[1]=="ILVabsent") noILVmulti<-0
	
	datalength <- length(nbdadata@id) #ILV effects on social transmission
	
	#Extract vector giving which naive individuals were present in the diffusion for each acqusition event
	presentInDiffusion<-nbdadata@ presentInDiffusion
	
	#assign different paramreter values to the right vectors
	sParam <- parVect[1:noSParam]
	asocialCoef <- parVect[(noSParam+1):(noSParam+ noILVasoc)]
	intCoef<- parVect[(noSParam+noILVasoc+1):(noSParam+ noILVasoc+noILVint)]
	multiCoef<-parVect[(noSParam+noILVasoc+noILVint+1):(noSParam+ noILVasoc+noILVint+noILVmulti)]
	
	if(nbdadata@asoc_ilv[1]=="ILVabsent") asocialCoef<-NULL
	if(nbdadata@int_ilv[1]=="ILVabsent") intCoef<-NULL
	if(nbdadata@multi_ilv[1]=="ILVabsent") multiCoef<-NULL
	  
	# create a matrix of the coefficients to multiply by the observed data values, only if there are asocial variables 
	if(nbdadata@asoc_ilv[1]=="ILVabsent"){
	  asocialLP<-rep(0,datalength)
	}else{
  	asocialCoef.mat <- matrix(data=rep(asocialCoef, datalength), nrow=datalength, byrow=T)
	  asocial.sub <- nbdadata@asocILVdata
	  asocialLP <- apply(asocialCoef.mat*asocial.sub, MARGIN=1, FUN=sum)
	}
	asocialLP<-asocialLP+nbdadata@offsetCorrection[,2]

	# now do the same for the interaction variables
	if(nbdadata@int_ilv[1]=="ILVabsent"){
	  socialLP<-rep(0,datalength)
	}else{
	  intCoef.mat <- matrix(data=rep(intCoef, datalength), nrow=datalength, byrow=T)
	  int.sub <- nbdadata@intILVdata
	  socialLP <- apply(intCoef.mat*int.sub, MARGIN=1, FUN=sum)
	}
	socialLP<-socialLP+nbdadata@offsetCorrection[,3]
	
	# now adjust both LPs for the variables specified to have a multiplicative effect (the same effect on asocial and social learning)
	if(nbdadata@multi_ilv[1]=="ILVabsent"){
	  multiLP<-rep(0,datalength)
	}else{
	  multiCoef.mat <- matrix(data=rep(multiCoef, datalength), nrow=datalength, byrow=T)
	  multi.sub <- nbdadata@multiILVdata
	  multiLP <- apply(multiCoef.mat*multi.sub, MARGIN=1, FUN=sum)
	}
	multiLP<-multiLP+nbdadata@offsetCorrection[,4]
	asocialLP<-asocialLP+multiLP
	socialLP<-socialLP+multiLP

	sParam.mat <- matrix(data=rep(sParam, datalength), nrow=datalength, byrow=T) # create a matrix of sParams 
	unscaled.st <- apply(sParam.mat*nbdadata@stMetric, MARGIN=1, FUN=sum)
	unscaled.st<-unscaled.st+nbdadata@offsetCorrection[,1]
	
	#The totalRate is set to zero for naive individuals not in the diffusion for a given event
	totalRate <- (exp(asocialLP) + exp(socialLP)*unscaled.st)* presentInDiffusion
		
	#This allows us to use tapply and return the correct order of events
	event.id_factor<-factor(nbdadata@event.id, levels=unique(nbdadata@event.id))
	
	#Take logs
	#DOing it using tapply means the events are ordered in the same way as for naive individuals
	lComp1 <- log(tapply(totalRate*nbdadata@status, INDEX=event.id_factor, FUN=sum))# group by skilled
	
	lComp2.1 <- tapply(totalRate, INDEX=event.id_factor, FUN=sum) # check this works. this is total rate per event across all naive id
	lComp2.2 <- log(lComp2.1)
	
	negloglik <- lComp2.2 - lComp1
	
	#Also get solver's st Metric and total st Metric
	learnersStMetric<-tapply(nbdadata@stMetric*nbdadata@status,event.id_factor,sum)
	totalStMetric<-tapply(nbdadata@stMetric,event.id_factor,sum)
	
	
	return(cbind(learnersStMetric,totalStMetric,negloglik))
	}
}


