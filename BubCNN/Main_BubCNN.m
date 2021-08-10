% Copyright (c) Institut für Industrieofenbau RWTH Aachen University  - All Rights Reserved
% Unauthorized copying of this file, via any medium is strictly prohibited
% Proprietary and confidential
% Written by Tim Haas <haas@iob.rwth-aachen.de>, 2019

clearvars;
close all;

%% load pretrained Data

[file,path]=uigetfile('*.mat','Load Faster RCNN Module');
transferModule=fullfile(path,file);
load(transferModule);
[file,path]=uigetfile('*.mat','Load Shape Regression Module');
shapeModule=fullfile(path,file);
load(shapeModule);
regressorNet=trainedNet;
%%
% load image(s) or video
[fileName, pathName] = uigetfile({'*.png;*.jpg;*.bmp;*.tif;*.mp4;*.avi;*.mkv;*.mov'}, ...
    'Select image or video files','MultiSelect','on');
error = false;

if isequal(fileName,0)
    errordlg('Image could not be found or loaded. Make sure to only submit supported images or video files','Error');
    
else
    if iscell(fileName)
        
        for currentImage = 1 : 1 : size(fileName,2)
            if endsWith(fileName{1}, ".png") || endsWith(fileName{1}, ".bmp") || endsWith(fileName{1}, ".jpg") || endsWith(fileName{1}, ".jpeg") || endsWith(fileName{1}, ".tiff")
                image = imread([pathName fileName{currentImage}]);
                data.images(currentImage) = struct('cdata',image,'colormap',[]);
                %todo error unequal image sizes
            else
                error = true;
            end
        end
    else
        if endsWith(fileName, ".png") || endsWith(fileName, ".bmp") || endsWith(fileName, ".jpg") || endsWith(fileName, ".jpeg") || endsWith(fileName, ".tiff")|| endsWith(fileName, ".JPG")
            isimage = true;
            image = imread([pathName fileName]);
            data.images = struct('cdata',image,'colormap',[]);
            
            currentImage = 1;
        elseif endsWith(fileName, ".avi") || endsWith(fileName, ".mkv") || endsWith(fileName, ".mp4")|| endsWith(fileName, ".MOV")
            ismovie = true;
            vid = VideoReader([pathName fileName]);
            vidWidth = vid.Width;
            vidHeight = vid.Height;
            data.images = repmat(struct('cdata', zeros(vidHeight,vidWidth,3,'uint8'),'colormap',[]), vid.NumberOfFrames, 1);
            vid = VideoReader([pathName fileName]);
            currentImage = 1;
            while hasFrame(vid)
                data.images(currentImage).cdata = readFrame(vid);
                currentImage = currentImage+1;
            end
            currentImage = currentImage-1;
        else
            error = true;
        end
    end
    
    if ~error
        
        data.noImages = currentImage;
        
    else
        errordlg('Image could not be found or loaded. Make sure to only submit supported images or video files','Error');
    end
end


%%
f = uifigure;
detectedEllipses=cell(data.noImages,1);
minConfLevel=0.95;

for evaluatedImage=1:data.noImages
    evaluatedImage/data.noImages*100
    progressBar = uiprogressdlg(f,'Title','Please Wait',...
        'Message','Run Faster RCNN module');
    progressBar.Value = ((evaluatedImage*2)-1)/(data.noImages*2);
    currentImage=data.images(evaluatedImage).cdata;
    [imageHeight,imageWidth,colorChannel]=size(currentImage);
    if colorChannel<3
        currentImage=repmat (currentImage,1,1,3);
    end
    % Search bounding boxes with FasterRCNN module
    [boundBoxes,boxConfLevel] = detect(owndetector,currentImage,'SelectStrongest',false,'NumStrongestRegions',Inf);
    P=find(boxConfLevel<minConfLevel);
    boundBoxes(P,:)=[];
    boxConfLevel(P)=[];
    % Delete overlapping boxes
    if ~isempty(boxConfLevel)
        [boundBoxes,boxConfLevel] = selectStrongestBbox(boundBoxes, boxConfLevel,'OverlapThreshold',0.5,'RatioType','Min');
    end
    
    
    % Annotate detections in the image.
    fh=figure;
    subplot(1,2,1)
    bBoxPlot = insertShape(((rgb2gray(currentImage))),'rectangle',boundBoxes, 'LineWidth', 4, 'Color','blue');
    imshow(bBoxPlot);
    title('Faster RCNN')
    subplot(1,2,2)
    imshow((rgb2gray(currentImage)));
    title('Faster RCNN + Regression CNN');
    [noBoxes,~]=size(boundBoxes);
    positionIndexes=[1,2];
    for b=1:noBoxes
        [m,index]=max(boundBoxes(b,3:4));
        diff=abs(boundBoxes(b,3)-boundBoxes(b,4));
        rescalingFactor=m/64;
        boundBoxes(b,find(positionIndexes~=index))=max(boundBoxes(b,find(positionIndexes~=index))-round(diff/2),1);
        boundBoxes(b,3:4)=m;
        if boundBoxes(b,1)+boundBoxes(b,3)>imageWidth
            boundBoxes(b,1)=boundBoxes(b,1)-(boundBoxes(b,1)+boundBoxes(b,3)-imageWidth);
        end
        if boundBoxes(b,1)<1
            boundBoxes(b,1)=1;
        end
        if boundBoxes(b,2)+boundBoxes(b,4)>imageHeight
            boundBoxes(b,2)=boundBoxes(b,2)-(boundBoxes(b,2)+boundBoxes(b,4)-imageHeight);
        end
        if boundBoxes(b,2)<1
            boundBoxes(b,2)=1;
        end
        regInputWindow=currentImage(boundBoxes(b,2):boundBoxes(b,2)+boundBoxes(b,4),boundBoxes(b,1):boundBoxes(b,1)+boundBoxes(b,3));
        regInputWindow=imresize(regInputWindow,[64 64]);
        approxBubbles(b,1:6)=(predict(regressorNet,regInputWindow)).*(S)+mumean;
        
        approxBubbles(b,1:4)=approxBubbles(b,1:4).*rescalingFactor;
        approxBubbles(b,1)=approxBubbles(b,1)+boundBoxes(b,1);
        approxBubbles(b,2)=approxBubbles(b,2)+boundBoxes(b,2);
        approxBubbles(b,5)=atan(approxBubbles(b,5)/approxBubbles(b,6))/2;
        progressBar.Value = evaluatedImage/data.noImages;
        progressBar.Message = 'Run shape regression CNN';
        hold on;
        bubbleOutline=plotellipse(approxBubbles(b,1:2),approxBubbles(b,3),approxBubbles(b,4),approxBubbles(b,5));
        bubbleOutline.LineWidth=3;
        bubbleOutline.Color='red';
        hold on;
        plot(approxBubbles(b,1),approxBubbles(b,2),'+','MarkerSize',10);
        
        
    end
    % delete (fh)
    detectedEllipses{evaluatedImage}=approxBubbles(:,1:5);
end
delete (f)
save('Detectionresults.mat','detectedEllipses');
