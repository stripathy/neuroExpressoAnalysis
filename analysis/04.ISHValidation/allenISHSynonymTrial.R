# devtools::install_github('oganm/allenBrain')
library(allenBrain)
library(assertthat)
library(geneSynonym)
devtools::load_all()

genes = mouseMarkerGenes$Hippocampus

granuleMarkers = genes$DentateGranule

genes = mouseMarkerGenes$Cerebellum

purkinjeMarkers  = genes$Purkinje


# loop is only around markers so don't bother commenting others out
# Prox1 and Pcp2 are full markers, removed at the creation of the single pages for pdf
markers = list(DentateGranule = c(granuleMarkers,'Prox1'),
               Purkinje = c(purkinjeMarkers,'Pcp2'))

# markers = list(DentateGranule = c('Prox1'),
#                Purkinje = c('Pcp2'))

IDs = getStructureIDs()
granuleID = IDs[grepl('^hippocampal region',IDs$name),]$id
purkinjeID = IDs[grepl('^cerebellum$', IDs$name),]$id



ids = c(granule = granuleID,
        purkinje = purkinjeID)

xProportions = list(DentateGranule = c(0.17,0.08),
                    Purkinje = c(0.15,0.15))

yProportions = list(DentateGranule = c(0.125,0.125),
                    Purkinje = c(.25,.20))



# get raw image
for(i in 1:len(markers)){
    dir.create(paste0('analysis//05.ISHValidation/',names(markers)[i],'_full'),recursive=TRUE,showWarnings=FALSE)
    dir.create(paste0('analysis//05.ISHValidation/',names(markers)[i]),recursive=TRUE,showWarnings=FALSE)
    
    for (j in 1:len(markers[[i]])){
        filenameFull = paste0('analysis/05.ISHValidation/',names(markers)[i],'_full','/',markers[[i]][j],'_projection.jpg')
        filename = paste0('analysis/05.ISHValidation/',names(markers)[i],'/',markers[[i]][j],'_projection.jpg')
        tryCatch({
            datasetID = getGeneDatasets(gene = markers[[i]][j],planeOfSection = 'sagittal')[1]
            imageID = getImageID(datasetID = datasetID, regionID = ids[i])
            if(any(is.na(imageID)) | is.null(datasetID[[1]])){
                synonyms = mouseSyno(markers[[i]][j]) %>% unlist %>% {.[!.%in% markers[[i]][j]]}
                k=1
                while(any(is.na(imageID)) | is.null(datasetID[[1]])){
                    datasetID = getGeneDatasets(gene = synonyms[k],planeOfSection = 'sagittal')[1]
                    imageID = getImageID(datasetID = datasetID, regionID = ids[i])
                    k = k+1
                    if(k>length(synonyms)){
                        break
                    }
                }
                if(any(is.na(imageID)) | is.null(datasetID[[1]])){
                    next
                }
            }
            
            dowloadImage(imageID["imageID"], view = 'projection',
                         output = filenameFull)
            centerImage(imageFile = filenameFull, x = imageID['x'],
                        y= imageID['y'],
                        xProportion = xProportions[[i]],
                        yProportion = yProportions[[i]],
                        outputFile = filename)
        },  error=function(cond){
            print('meh')  
        })
    }
}

# get processed expression image
for(i in 1:len(markers)){
    for (j in 1:len(markers[[i]])){
        filenameFull = paste0('analysis/05.ISHValidation/',names(markers)[i],'_full','/',markers[[i]][j],'_expression.jpg')
        filename = paste0('analysis/05.ISHValidation/',names(markers)[i],'/',markers[[i]][j],'_expression.jpg')
        tryCatch({
            datasetID = getGeneDatasets(gene = markers[[i]][j],planeOfSection = 'sagittal')[1]
            imageID = getImageID(datasetID = datasetID, regionID = ids[i])
            dowloadImage(imageID["imageID"], view = 'expression',
                         output = filenameFull)
            centerImage(imageFile = filenameFull, x = imageID['x'],
                        y= imageID['y'],
                        xProportion = xProportions[[i]],
                        yProportion = yProportions[[i]],
                        outputFile = filename)
        },  error=function(cond){
            print('meh')  
        })
    }
}


# resize all images to 700x500 px and label the projection images
# this part does not work as intended in chalmers due to imagemagick version (must be )
lapply(names(markers), function(x){
    dir.create(paste0('analysis/05.ISHValidation/',x,'_resize'))
    files = list.files(paste0('analysis/05.ISHValidation/',x), full.names=TRUE)
    files %>% lapply(function(y){
        system(paste0('convert ', y,' -resize 700x500\\> -background black -gravity center -extent 700x500 analysis/05.ISHValidation/',x,'_resize/',basename(y)))
        if(grepl(pattern='projection',y)){
            system(paste0("convert ",
                          'analysis/05.ISHValidation/',x,'_resize/',basename(y),
                          ' -fill black -undercolor white -gravity NorthWest -pointsize 29 -annotate +5+5 \'',
                          basename(y) %>% str_extract(".*(?=_)"),
                          '\'',
                          ' analysis/05.ISHValidation/',x,'_resize/',basename(y)))
            
        }
        # add borders
        system(paste0('convert ',
                      'analysis/05.ISHValidation/',x,'_resize/',basename(y),
                      ' -background black -gravity Center -extent 700x510 ',
                      ' analysis/05.ISHValidation/',x,'_resize/',basename(y)))
        
        if(grepl(pattern = 'projection', y)){
            system(paste0('convert ',
                          'analysis/05.ISHValidation/',x,'_resize/',basename(y),
                          ' -background black -gravity East -extent 705x510 ',
                          ' analysis/05.ISHValidation/',x,'_resize/',basename(y)))
            
        } else if(grepl(pattern = 'expression', y)){
            system(paste0('convert ',
                          'analysis/05.ISHValidation/',x,'_resize/',basename(y),
                          ' -background black -gravity West -extent 705x510 ',
                          ' analysis/05.ISHValidation/',x,'_resize/',basename(y)))
        }
        
    })
})

# convert to png so compression will not cause problems later on
# lapply(names(markers), function(x){
#     dir.create(paste0('analysis//05.ISHValidation/',x,'_resize_png'))
#     files = list.files(paste0('analysis//05.ISHValidation/',x,'_resize'), full.names=TRUE)
#     files %>% lapply(function(y){
#         system(paste0('convert ', y,' ',
#                       'analysis/05.ISHValidation/',x,'_resize_png/',basename(y) %>% str_extract('.*?(?=[.])'),
#                       '.png'))
#     })
# })


lapply(names(markers), function(x){
    dir.create(paste0('analysis//05.ISHValidation/',x,'_doubleMerged'))
    files = list.files(paste0('analysis//05.ISHValidation/',x,'_resize'), full.names=TRUE)
    projection = files[grepl('projection',files)]
    expression = files[grepl('expression',files)]
    
    # if not true something is fucked up
    assert_that(len(projection)==len(expression))
    for (i in 1:len(projection)){
        # if not true something is fucked up
        assert_that((basename(projection[i]) %>% strsplit(split = '_') %>% {.[[1]][1]}) == 
                        (basename(expression[i]) %>% strsplit(split = '_') %>% {.[[1]][1]}))
        
        
        system(paste0('convert ',
                      projection[i], ' ', expression[i], ' -quality 100 +append ',
                      'analysis//05.ISHValidation/',x,'_doubleMerged/', basename(projection[i])
        ))
    }
    
})

lapply(names(markers), function(x){
    dir.create(paste0('analysis//05.ISHValidation/',x,'_singlePages'))
    files = list.files(paste0('analysis//05.ISHValidation/',x,'_doubleMerged'), full.names=TRUE)
    files = files[!grepl('(Prox1)|(Pcp2)',files)]
    iterate = seq(from=1,to=len(files),by=4)
    for(i in iterate){
        theseFiles = files[i:(i+3)] %>% trimNAs()
        system(paste0('convert ',
                      paste(theseFiles,collapse = ' '),
                      ' -quality 100 -append ',
                      'analysis//05.ISHValidation/',x,'_singlePages/', formatC(i,width=2, flag="0"),'.png'))
    }
    
})

lapply(names(markers),function(x){
    df = data.frame(Gene = markers[[x]])
    df$Status = df$Gene %>% sapply(function(y){
        grepl(y,list.files(paste0('analysis//05.ISHValidation/',x,'_doubleMerged'))) %>% any
    }) %>% replaceElement(labels = c(TRUE,FALSE),dictionary = c('','not in ABA')) %$% newVector
    write.design(df,file = paste0('analysis//05.ISHValidation/',x,'.tsv'))
})
