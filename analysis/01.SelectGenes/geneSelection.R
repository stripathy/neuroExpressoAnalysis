# here we select marker genes provided in the object "mouseBrainMarkers" This script can run as a whole
# or can be run from the command line to divide up the rotation process.
# usage: Rscript geneSelection.R [start] [end] [secondChip]
# start and end are intigers that provide the interval of permutations
# 500 permutations are performed for this study
# if start = 1, quick selection will be performed by the script
# if end = 500 the script will wait for the output folder to be filled with 500
# permutations and finishes the gene selection process.
# second chip controls whether or not genes should be selected exclusively for GPL1261
# the default output location is data-raw. Other directories will be created if not already
# existing
devtools::load_all()
library(markerGeneProfile)
library(jsonlite)
library(stringi)
library(bitops)
library(XLConnect)
#library(markerGenesManuscript)

print('it starts')
if(length(commandArgs(trailingOnly=TRUE))==0){
    start = 1
    end = 500
    firstChip = TRUE
    secondChip = FALSE
    singleCell = TRUE
} else{
    args <- commandArgs(trailingOnly = TRUE)
    start = as.numeric(args[1])
    end = as.numeric(args[2])
    firstChip = as.logical(args[5])
    if(is.na(firstChip)){
        firstChip = TRUE
    }
    secondChip = as.logical(args[3])
    singleCell = as.logical(args[4])
}


# quick selection ---------------------------
if (start == 1){
    # this is a quick way to select "good enough" markers without doing permutations
    # output of this will not be robust to outliers. These genes are not used in the study
    # and are not readily available in the package
    if(singleCell){
        ptm <- proc.time()
        
        markerCandidates(design = meltedSingleCells,foldChangeThresh = 10,minimumExpression = 2.5, background = 0.1,
                         expression = data.frame(Gene.Symbol = rn(TasicPrimaryMeanLog),TasicPrimaryMeanLog,check.names = FALSE),
                         outLoc = 'analysis//01.SelectGenes/QuickJustSingleCell',
                         groupNames = c('PyramidalDeep','CellTypes'),
                         #groupNames = 'DopaSelect',
                         #groupNames = c('AstroInactiveAlone','AstroReactiveAlone'),
                         regionNames = NULL,
                         cores=15,
                         regionHierarchy= NULL)
        singleCellTime = proc.time() - ptm
        
    }
    
    if(firstChip){
        ptm <- proc.time()
        markerCandidates(design = n_expressoSamples,
                         expression = n_expressoExpr,
                         outLoc = 'analysis//01.SelectGenes/Quick',
                         groupNames = c('PyramidalDeep','CellTypes'),
                         #groupNames = 'DopaSelect',
                         #groupNames = c('AstroInactiveAlone','AstroReactiveAlone'),
                         regionNames = 'Region',
                         cores=15,
                         regionHierarchy = regionHierarchy)
        neuroExpTime = proc.time() - ptm
        
    }
    # quickly select genes exlusively for the samples from GPL1261. These genes are not used in the study and are not
    # readily available in the package
    if (secondChip){
        markerCandidates(design = 
                             ogbox::read.design('data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv'),
                         expression =
                             ogbox::read.exp('data-raw/Mouse_Cell_Type_Data/n_expressoExpr2.csv'),
                         outLoc = 'analysis//01.SelectGenes/Quick2',
                         groupNames = c('PyramidalDeep','BroadTypes','DopaSelect'),
                         #groupNames = 'DopaSelect',
                         #groupNames = c('AstroInactiveAlone','AstroReactiveAlone'),
                         regionNames = 'Region',
                         cores=15,
                         regionHierarchy = regionHierarchy)
    }
}


# rotations ----------------------------
if(start==1){
    file.create('analysis//01.SelectGenes/Rotation/progress')
}
if(firstChip){
    for (i in start:end){
        print(i)
        ptm <- proc.time()
        markerCandidates(design = n_expressoSamples,
                         expression = n_expressoExpr,
                         outLoc = paste0('analysis//01.SelectGenes/Rotation/',i),
                         groupNames = c('PyramidalDeep','CellTypes'),
                         regionNames = 'Region',
                         rotate=0.33,
                         regionHierarchy = regionHierarchy,
                         cores=15,
                         seed = i)
        firstChipRotationTime = proc.time() - ptm
    }
    cat(paste(start,end,'\n'),file='analysis//01.SelectGenes/Rotation/progress',append=TRUE)
    
}

# rotation with single cells ------------------------------
if(singleCell){
    if(start==1){
        file.create('analysis//01.SelectGenes/RotationJustSingleCell/progress')
    }
    for(i in start:end){
        ptm <- proc.time()
        markerCandidates(design = meltedSingleCells,foldChangeThresh = 10, minimumExpression = 2.5, background = 0.1,
                         expression = data.frame(Gene.Symbol = rn(TasicPrimaryMeanLog),TasicPrimaryMeanLog,check.names = FALSE),
                         outLoc = paste0('analysis//01.SelectGenes/RotationJustSingleCell/',i),
                         groupNames = c('PyramidalDeep','CellTypes'),
                         regionNames = NULL,
                         cores=15,
                         rotate = 0.33,
                         regionHierarchy= NULL)
        singleRotationTime = proc.time() - ptm
        
        
    }
    cat(paste(start,end,'\n'),file='analysis//01.SelectGenes/RotationJustSingleCell/progress',append=TRUE)
}
# second chip rotations -------------------
if(secondChip){
    if(start==1){
        file.create('analysis//01.SelectGenes/Rotation2/progress')
    }
    for (i in start:end){
        print(i)
        markerCandidates(design = 
                             ogbox::read.design('data-raw/Mouse_Cell_Type_Data/n_expressoSamples2.tsv'),
                         expression = 
                             ogbox::read.exp('data-raw/Mouse_Cell_Type_Data/n_expressoExpr2.csv'),
                         outLoc = paste0('analysis//01.SelectGenes/Rotation2/',i),
                         groupNames = c('PyramidalDeep','BroadTypes','DopaSelect'),
                         #groupNames = 'DopaSelect',
                         #groupNames = c('AstroInactiveAlone','AstroReactiveAlone'),
                         regionNames = 'Region',
                         rotate=0.33,
                         cores=15,
                         regionHierarchy = regionHierarchy,
                         seed = i)
    }
    cat(paste(start,end,'\n'),file='analysis//01.SelectGenes/Rotation2/progress',append=TRUE)
    
}

# RotSel: if this is the last rotation, calculate the selection percentages of genes. ----------------
if(end == 500){
    # wait for all other branches to complete operation
    if(firstChip){
        repeat{
            progress = read.table('analysis//01.SelectGenes/Rotation/progress') %>% apply(1, function(x){
                x[1]:x[2]
            }) %>% sapply(len) %>% sum
            if (progress>=500){
                break
            }
            Sys.sleep(60) 
        }
        
        print('waiting complete')
        rotateSelect(rotationOut='analysis//01.SelectGenes/Rotation/',
                     rotSelOut='analysis/01.SelectGenes/RotSel',
                     cores = 15,foldChange = 1)
    }
    # rotsel second chip
    if(secondChip){
        repeat{
            progress = read.table('analysis//01.SelectGenes/Rotation2/progress') %>% apply(1, function(x){
                x[1]:x[2]
            }) %>% sapply(len) %>% sum
            if (progress>=500){
                break
            }
            Sys.sleep(60) 
        }
        rotateSelect(rotationOut='analysis//01.SelectGenes/Rotation2/',
                     rotSelOut='analysis/01.SelectGenes/RotSel2',
                     cores = 15, foldChange = 1)
    }
    # rotsel single cells
    if(singleCell){
        repeat{
            progress = read.table('analysis//01.SelectGenes/RotationJustSingleCell//progress') %>% apply(1, function(x){
                x[1]:x[2]
            }) %>% sapply(len) %>% sum
            if (progress>=500){
                break
            }
            Sys.sleep(60) 
        }
        # rotateSelect(rotationOut='analysis//01.SelectGenes/RotationSingleCell//',
        #              rotSelOut='analysis/01.SelectGenes/RotSelSingleCell',
        #              cores = 16, foldChange = 1)
        
        rotateSelect(rotationOut='analysis//01.SelectGenes/RotationJustSingleCell//',
                     rotSelOut='analysis/01.SelectGenes/RotSelJustSingleCell',
                     cores = 15, foldChange = 1)
    }
    
    # rotsel folder creation -------------------------------
    
    if(firstChip){
        allGenes = list(genes1 = pickMarkersAll('analysis/01.SelectGenes/RotSel/'))
        names = 'Markers_Microarray'
    } else {
        allGenes$gene1 = NA
        names = NA
    }
    
    if (secondChip){
        allGenes = c(allGenes = allGenes[[1]],
                     list(genes3 = pickMarkersAll('analysis/01.SelectGenes/RotSel/')))
        names = c(names,'Markers_LargeMicroarray')
    } else{
        allGenes$gene2=NA
        names = c(names,NA)
    }
    if(singleCell){
        allGenes = c(allGenes, #list(genes3 = pickMarkersAll('analysis/01.SelectGenes/RotSelSingleCell/')),
                     list(genes3 = pickMarkersAll('analysis/01.SelectGenes/RotSelJustSingleCell//')))
        names = c(names,'Markers_SingleCell')
    }
    
    for (n in 1:len(allGenes)){
        if(is.na(names[[n]])){
            next
        }
        genes = allGenes[[n]]
        for (i in 1:len(genes)){
            pieces = strsplit(names(genes)[i],'_')[[1]]
            if (is.na(pieces[2])){
                pieces[2] = pieces[1]
                pieces[1] ='All'
            }
            dir.create(paste0('analysis//01.SelectGenes/',names[n],'/',
                              pieces[2] , '/' , pieces[1]), 
                       showWarnings=F, recursive=T)
            
            
            for (j in 1:len(genes[[i]])){
                write.table(genes[[i]][[j]]  %>%{.[!grepl('\\|',x = .)]} ,
                            paste0('analysis//01.SelectGenes/',names[n],'/',
                                   pieces[2],'/',pieces[1],'/', 
                                   names(genes[[i]])[j]),
                            row.names=F,
                            quote=F,
                            col.names=F      
                )
            }
        }
    }
    
    # here we do some wrangling of the gene list to deal with astrocytes and microglia
    referenceGroup = 'PyramidalDeep'
    log = 'analysis/01.SelectGenes/markers.log'
    
    # this is to count what changed about the microglia genes in the combined list
    oldMicroglia = list()
    oldMicroglia[['Microarray']] = pickMarkersAll("analysis//01.SelectGenes/Markers_Microarray/PyramidalDeep")$Cortex$Microglia
    oldMicroglia[['RNAseq']] = pickMarkersAll("analysis//01.SelectGenes/Markers_SingleCell/PyramidalDeep")$All$Microglia
    
    file.create(log)
    for(i in 1:len(names)){
        if(is.na(names[i])){
            next
        }
        cat(paste0(names[i],'\n########\n'),file = log,append = TRUE)
        cat('Microglial Exception\n---------------\n', file = log, append = TRUE)
        
        genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/',referenceGroup))
        allMicroglia = genes %>% lapply(function(x){
            x['Microglia']
        }) %>% unlist %>% unique %>% len
        cat(paste0('Microglia used to have ', allMicroglia, ' genes\n'), file = log,append = TRUE)
        
        microglialException(paste0('analysis//01.SelectGenes/',names[i]),cores=8)
        
        genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/',referenceGroup))
        allMicroglia = genes %>% lapply(function(x){
            x['Microglia']
        }) %>% unlist %>% unique %>% len
        cat(paste0('Microglia now have ', allMicroglia, ' genes\n\n'), file = log,append = TRUE)
        
        
        
        
        if(!grepl('SingleCell',names[i])){
            cat('S100a10 Exception\n--------------------\n',file=log,append = TRUE)
            genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/','PyramidalDeep'))
            
            allS100 = genes %>% lapply(function(x){
                x['Pyramidal_S100a10']
            }) %>% unlist %>% unique %>% len
            cat(paste0('S100a10 pyramdials used to have ', allS100, ' genes\n'),file=log,append=TRUE)
            
            allowGenes(paste0('analysis//01.SelectGenes/',names[i]),
                       allowedGenes = allowedProbesS100a10,
                       regex = 'S100a10',
                       cores = 8)
            
            # s100a10exception(paste0('analysis//01.SelectGenes/',names[i]),cores=8)
            
            genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/','PyramidalDeep'))
            allS100 = genes %>% lapply(function(x){
                x['Pyramidal_S100a10']
            }) %>% unlist %>% unique %>% len
            
            cat(paste0('S100a10 pyramdials now have ', allS100, ' genes\n\n'),file=log,append=TRUE)
            
            cat('Granule Exception\n--------------------\n',file=log,append = TRUE)
            genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/','PyramidalDeep'))
            allDentate = genes %>% lapply(function(x){
                x['DentateGranule']
            }) %>% unlist %>% unique %>% len
            cat(paste0('Granule cells used to have ', allDentate, ' genes\n'),file=log,append=TRUE)
            
            allowGenes(paste0('analysis//01.SelectGenes/',names[i]),
                       allowedGenes = granuleAllowedGenes,
                       regex = 'DentateGranule',
                       cores = 8)
            
            genes = pickMarkersAll(paste0('analysis//01.SelectGenes/',names[i],'/','PyramidalDeep'))
            allDentate = genes %>% lapply(function(x){
                x['DentateGranule']
            }) %>% unlist %>% unique %>% len
            cat(paste0('Granule cells now have ', allDentate, ' genes\n'),file=log,append=TRUE)
            
        }
        
        bannedGenes = c('Lpl')
        banGenes(restDir = paste0('analysis//01.SelectGenes/',names[i],'/'),
                 bannedGenes= bannedGenes,
                 cores=8)
        
        bannedGenes = 'S100a10'
        banGenes(restDir = paste0('analysis//01.SelectGenes/',names[i],'/'),
                 bannedGenes= bannedGenes,
                 regex= 'S100a10',
                 cores=8)        
    }
    
    # counting microglia genes again. not necesarry for analysis -------------------
    newMicroglia = list()
    newMicroglia[['Microarray']] = pickMarkersAll("analysis//01.SelectGenes/Markers_Microarray/CellTypes")$Cortex$Microglia
    newMicroglia[['RNAseq']] = pickMarkersAll("analysis//01.SelectGenes/Markers_SingleCell/CellTypes")$All$Microglia
    
    # calculate how many genes microglia would have had

    microRNAseq = list(new = newMicroglia$RNAseq,
                       old = oldMicroglia$RNAseq)
    microMicroarray = list(new = newMicroglia$Microarray,
                           old = oldMicroglia$Microarray)
    
    trimMicroarray = 1:length(microMicroarray) %>% lapply(function(i){
        genes = microMicroarray[[i]]
        name = 'Microglia'
        out = c(genes[teval(paste0("tasicSimpleMarkers_",referenceGroup))[genes] == name], genes[is.na(teval(paste0("tasicSimpleMarkers_",referenceGroup))[genes])]) %>% trimNAs()
    })
    
    trimRNASeq = 1:length(microRNAseq) %>% lapply(function(i){
        genes = microMicroarray[[i]]
        name = 'Microglia'
        out = c(genes[teval(paste0("tasicSimpleMarkers_",referenceGroup))[genes] == name], genes[is.na(teval(paste0("nxSimpleMarkers_",referenceGroup))[genes])]) %>% trimNAs()
    })
    
    oldGenes = len(trimMicroarray[[2]]) + len(trimRNASeq[[2]])
    newGenes = len(trimMicroarray[[1]]) + len(trimRNASeq[[1]])
    cat(glue::glue('\nMicrglia together would have had {oldGenes} genes.\nMicroglia together has {oldGenes-newGenes} genes' ),file=log,append=TRUE)
    
    
    # merge single cell genes for cortex -----------
    typeSets = list.files('analysis/01.SelectGenes/Markers_Microarray/')

    dir.create('analysis/01.SelectGenes/Markers_Final')
    system('cp -r analysis/01.SelectGenes/Markers_Microarray/* analysis/01.SelectGenes/Markers_Final')
    #system('cp -r analysis/01.SelectGenes/Markers_Microarray analysis/01.SelectGenes/Markers_FinalRelax')
    
    if(firstChip & singleCell){

        for (x in typeSets){
            original = pickMarkers(file.path('analysis/01.SelectGenes/Markers_Microarray',x,'/Cortex/'))
            singleCells = pickMarkers(paste0("analysis/01.SelectGenes/Markers_SingleCell/",x,"/All/"))

            frame = names(singleCells) %>% sapply(function(y){
                c(nx = {
                    if(is.null(original[[y]])){
                        NA
                    } else{
                        original[[y]] %>% length
                    }
                },
                singleCells = singleCells[[y]] %>% length)
            },simplify=FALSE) %>% as.df %>% t
            
            
            trimOrig = 1:length(original) %>% lapply(function(i){
                genes = original[[i]]
                name = names(original)[i] %>% gsub(pattern = '(_activation)|(_deactivation)',replacement = '')
                out = c(genes[teval(paste0("tasicSimpleMarkers_",x))[genes] == name], genes[is.na(teval(paste0("tasicSimpleMarkers_",x))[genes])]) %>% trimNAs()
            })
            names(trimOrig) = names(original)
            
            
            trimSingle = 1:length(singleCells) %>% lapply(function(i){
                genes = singleCells[[i]]
                #names(original)[i]]
                name = names(singleCells)[i] %>% gsub(pattern = '(_activation)|(_deactivation)',replacement = '')
                if(!names(singleCells)[i] %in% names(original)){
                    return(genes)
                }
                out = c(genes[teval(paste0("nxSimpleMarkers_",x))[genes] == name],
                        genes[is.na(teval(paste0("nxSimpleMarkers_",x))[genes])]) %>% trimNAs()
            })
            names(trimSingle) = names(singleCells)
            

            frameTrim = names(singleCells) %>% sapply(function(y){
                c(nx = {
                    if(is.null(trimOrig[[y]])){
                        NA
                    } else{
                        trimOrig[[y]] %>% length
                    }
                },
                singleCells = trimSingle[[y]] %>% length)
            },simplify=FALSE) %>% as.df %>% t
            
            
            allMarkers = names(trimSingle) %>% sapply(function(i){
                c(trimSingle[[i]],trimOrig[[i]]) %>% unique
            },simplify=FALSE)
            
            frameAll = names(allMarkers) %>% sapply(function(x){
                c(total = allMarkers[[x]] %>% length)
            },simplify=FALSE) %>% as.df %>% t
            
            
            framePresent = 1:ncol(frameTrim) %>% sapply(function(i){
                paste0(frame[,i],' (',frameTrim[,i],')')
            })
            
            cn(framePresent) = cn(frameTrim)
            rn(framePresent) = rn(frameTrim)
            framePresent %<>% cbind(frameAll)

            write.table(framePresent,file = paste0('analysis/01.SelectGenes/cortexTable_',x,'.tsv'),sep = "\t", quote = F, row.names = T)
            
            
            for(i in 1:length(allMarkers)){
                write.table(allMarkers[i],
                        paste0('analysis/01.SelectGenes/Markers_Final/',
                               x,'/Cortex/',names(allMarkers)[i]),
                        row.names=F,
                        quote=F,
                        col.names=F)
            }
        }
    }
    
    #create the files that people will read ----------
    if(firstChip){
        library(XLConnect)
        genes = pickMarkersAll('analysis//01.SelectGenes/Markers_Final/PyramidalDeep/')
        genes2 = pickMarkersAll('analysis//01.SelectGenes/Markers_Final/CellTypes//')
        
        assertthat::are_equal(names(genes),names(genes2))
       
         mouseMarkerGenesCombined = lapply(1:length(genes),function(i){
             out = c(genes[[i]],genes2[[i]]['Pyramidal'])
             out = out[!(out %>% sapply(is.null))]
         })
        names(mouseMarkerGenesCombined) = names(genes)
        
        # assertthat::validate_that(all(!bannedGenes %in% unlist(genes)))
        
        mouseMarkerGenes = genes2
        mouseMarkerGenesPyramidalDeep = genes
        
        
        devtools::use_data(mouseMarkerGenes, overwrite=TRUE)
        devtools::use_data(mouseMarkerGenesPyramidalDeep, overwrite=TRUE)
        devtools::use_data(mouseMarkerGenesCombined, overwrite=TRUE)
        
        # dir.create('analysis/01.SelectGenes/Markers_Final')
        for(i in 1:length(mouseMarkerGenesCombined)){
            dir.create(paste0('analysis/01.SelectGenes/Markers_Final/Combined/',names(mouseMarkerGenesCombined)[i]),showWarnings = FALSE,recursive = TRUE)
            for(j in 1:length(mouseMarkerGenes[[i]])){
                write.table(mouseMarkerGenes[[i]][[j]],
                            paste0('analysis/01.SelectGenes/Markers_Final/Combined/',
                                   names(mouseMarkerGenes)[i],'/',
                                   names(mouseMarkerGenes[[i]][j])),
                            row.names=F,
                            quote=F,
                            col.names=F)
            }
        }
        
        toPlotGenes = mouseMarkerGenesCombined %>% lapply(function(x){
            x = x[!grepl('Microglia_',names(x))]
            x %<>% lapply(function(y){
                y[!grepl('[|]', y)]
            })
        })
        
            
        toPlotGenes %<>% lapply(function(x){
            x %<>%sapply(len)
            x[cellOrder] %>% trimNAs
            x = x[!grepl('Microglia_',names(x))]
            names(x) = publishableNameDictionary$ShinyNames[match(names(x),publishableNameDictionary$PyramidalDeep)]
            return(x)
        })
        
        toPlotGenes$All = toPlotGenes$All[c('Astrocyte','Oligodendrocyte','Microglia')]
        toPlotGenes[-1] %<>% lapply(function(x){
            x = x[!names(x) %in% c('Astrocyte','Oligodendrocyte','Microglia')]
        })
        # take the bottom ones in the region tree
        rockBottom = regionHierarchy %>% unlist %>% names %>% str_extract(pattern='(?<=[.])([A-Z]|[a-z])*$')
        rockBottom = c(rockBottom,'Midbrain')
        toPlotGenes = toPlotGenes[c('All', rockBottom)]
        
        toPlotGenes %<>% lapply(function(x){
            sapply(1:len(x),function(i){
                genes = x[i]
                samples = n_expressoSamplesWithRNAseq %>% filter(ShinyNames %in% names(x[i])) %>% nrow
                sources = 
                    n_expressoSamplesWithRNAseq %>% 
                    filter(ShinyNames %in% names(x[i])) %>% 
                    select(Reference,GSE) %>% 
                    unique %>% {
                        paste0(.[,1],' (', .[,2], ')')
                    } %>% paste(collapse = ', ')
                out = c(names(x[i]),samples, genes, sources )
                names(out) = NULL
                return(out)
            }) %>% as.data.frame %>% t
        }) 
        
        file.create('analysis/01.SelectGenes/geneTable.tsv')
        lapply(1:len(toPlotGenes), function(i){
            print(i)
            if(i == 1){
                append = FALSE
            } else {
                append = TRUE
            }
            cat(paste0(names(toPlotGenes)[i],'\n'),
                append = append,
                file= 'analysis/01.SelectGenes/geneTable.tsv')
            write.table(toPlotGenes[[i]], file = 'analysis/01.SelectGenes/geneTable.tsv',
                        sep = "\t",
                        quote = F, col.names = F,
                        row.names = F, append = TRUE)
        })
        
        # gene list in single files -------
        markerFiles = function(genes,outName){
            genes %>% toJSON(pretty=TRUE) %>% writeLines(paste0('analysis/01.SelectGenes/markerGenes',outName,'.json'))
            
            system(paste0('rm analysis/01.SelectGenes/markerGenes',outName,'.xls'))
            sheet = loadWorkbook(paste0('analysis/01.SelectGenes/markerGenes',outName,'.xls'), create = TRUE)
            dir.create(paste0('analysis/01.SelectGenes/markerGeneTSVs',outName), showWarnings = FALSE)
            1:len(genes) %>% sapply(function(i){
                out = stri_list2matrix(genes[[i]]) %>% as.data.frame
                names(out) = names(genes[[i]])
                write.table(out,file = paste0('analysis/01.SelectGenes/markerGeneTSVs',outName,'/',names(genes[i])),na= '', sep = "\t", quote = F, row.names = F)
                createSheet(sheet, name = names(genes[i]))
                writeWorksheet(sheet, out, sheet =  names(genes[i]), startRow = 1, startCol = 1)
            })
            saveWorkbook(sheet)
            
        }
        
        markerFiles(mouseMarkerGenes,'')
        markerFiles(mouseMarkerGenesPyramidalDeep,'PyraDeep')
        markerFiles(mouseMarkerGenesCombined,'Combined')
        
        # create archive
        file.remove('analysis/01.SelectGenes/markerGenes.rar')
        file.remove('analysis/01.SelectGenes/markerGenesPyraDeep.rar')
        file.remove('analysis/01.SelectGenes/markerGenesCombined.rar')
        
        system('rar -ep1 a analysis/01.SelectGenes/markerGenes.rar analysis/01.SelectGenes/Markers_Final/CellTypes')
        system('rar -ep1 a analysis/01.SelectGenes/markerGenesPyraDeep.rar analysis/01.SelectGenes/Markers_Final/PyramidalDeep/*')
        system('rar -ep1 a analysis/01.SelectGenes/markerGenesCombined.rar analysis/01.SelectGenes/Markers_Final/Combined/*')
    }
}
