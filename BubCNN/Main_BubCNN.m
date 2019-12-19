% Copyright (c) Institut für Industrieofenbau RWTH Aachen University  - All Rights Reserved
% Unauthorized copying of this file, via any medium is strictly prohibited
% Proprietary and confidential
% Written by Tim Haas <haas@iob.rwth-aachen.de>, 2019



clearvars;
close all;


%% load pretrained Data

 [file,path]=uigetfile('*.mat','Load Faster RCNN Module');  
        Transfermodule=fullfile(path,file);
        load(Transfermodule);
        [file,path]=uigetfile('*.mat','Load Shape Regression Module');  
        Shapemodule=fullfile(path,file);
        load(Shapemodule);
regressornet=trainedNet;
%%
% load image(s) or video
[FileName, PathName] = uigetfile({'*.png;*.jpg;*.bmp;*.tif;*.mp4;*.avi;*.mkv;*.mov'}, ...
    'Select image or video files','MultiSelect','on');
error = false;

if isequal(FileName,0)
    errordlg('Image could not be found or loaded. Make sure to only submit supported images or video files','Error');
    
else
    if iscell(FileName)
        
        for i = 1 : 1 : size(FileName,2)
            if endsWith(FileName{1}, ".png") || endsWith(FileName{1}, ".bmp") || endsWith(FileName{1}, ".jpg") || endsWith(FileName{1}, ".jpeg") || endsWith(FileName{1}, ".tiff")
                im = imread([PathName FileName{i}]);
                data.images(i) = struct('cdata',im,'colormap',[]);
                %todo error unequal image sizes
            else
                error = true;
            end
        end
    else
        if endsWith(FileName, ".png") || endsWith(FileName, ".bmp") || endsWith(FileName, ".jpg") || endsWith(FileName, ".jpeg") || endsWith(FileName, ".tiff")|| endsWith(FileName, ".JPG")
            isimage = true;
            im = imread([PathName FileName]);
            data.images = struct('cdata',im,'colormap',[]);
           
            i = 1;
        elseif endsWith(FileName, ".avi") || endsWith(FileName, ".mkv") || endsWith(FileName, ".mp4")|| endsWith(FileName, ".MOV")
            ismovie = true;
            vid = VideoReader([PathName FileName]);
            vidWidth = vid.Width;
            vidHeight = vid.Height;
            data.images = repmat(struct('cdata', zeros(vidHeight,vidWidth,3,'uint8'),'colormap',[]), vid.NumberOfFrames, 1);
            vid = VideoReader([PathName FileName]);
            i = 1;
            while hasFrame(vid)
            %for u=1:2 %change if for whole Video
                data.images(i).cdata = readFrame(vid);
                i = i+1;
            end
            i = i-1;
        else
            error = true;
        end
    end
    
    if ~error
        
        data.no_images = i;
        
    else
        errordlg('Image could not be found or loaded. Make sure to only submit supported images or video files','Error');
        app.delete;
    end
end


%%
f = uifigure;
detectedellipses=cell(data.no_images,1);

for evalimage=1:data.no_images
    evalimage/data.no_images*100
    d = uiprogressdlg(f,'Title','Please Wait',...
        'Message','Run Faster RCNN module');
    d.Value = ((evalimage*2)-1)/(data.no_images*2);
    I=data.images(evalimage).cdata;
    [imheight,imwidth,colchannel]=size(I);
    if colchannel<3
        I=repmat (I,1,1,3);
    end
    [bboxes,scores] = detect(owndetector,I,'SelectStrongest',false,'NumStrongestRegions',Inf);
         P=find(scores<0.95);
 bboxes(P,:)=[];
 scores(P)=[];
    
     if ~isempty(scores)
         [bboxes2,scores2] = selectStrongestBbox(bboxes, scores,'OverlapThreshold',0.5,'RatioType','Min');
     end


    % Annotate detections in the image.
    fh=figure;
    subplot(1,2,1)
    edg = insertShape(((rgb2gray(I))),'rectangle',bboxes2, 'LineWidth', 4, 'Color','blue');
    imshow(edg);
    title('Faster RCNN')
    subplot(1,2,2)
    imshow((rgb2gray(I)));
    title('Faster RCNN + Regression CNN');
    [boxlength,~]=size(bboxes2);
    newbox=bboxes2;
    posindexes=[1,2];
    for b=1:boxlength
        [m,index]=max(bboxes2(b,3:4));
        diff=abs(bboxes2(b,3)-bboxes2(b,4));
        factor=m/64;
        newbox(b,find(posindexes~=index))=max(bboxes2(b,find(posindexes~=index))-round(diff/2),1);
        newbox(b,3:4)=m;
        if newbox(b,1)+newbox(b,3)>imwidth
            newbox(b,1)=newbox(b,1)-(newbox(b,1)+newbox(b,3)-imwidth);
        end
        if newbox(b,1)<1
            newbox(b,1)=1;
        end
        if newbox(b,2)+newbox(b,4)>imheight
            newbox(b,2)=newbox(b,2)-(newbox(b,2)+newbox(b,4)-imheight);
        end
        if newbox(b,2)<1
            newbox(b,2)=1;
        end
        wind=I(newbox(b,2):newbox(b,2)+newbox(b,4),newbox(b,1):newbox(b,1)+newbox(b,3));
        wind=imresize(wind,[64 64]);
        Bubbles(b,1:6)=(predict(regressornet,wind)).*(S)+mumean;
        
        Bubbles(b,1:4)=Bubbles(b,1:4).*factor;
        Bubbles(b,1)=Bubbles(b,1)+newbox(b,1);
        Bubbles(b,2)=Bubbles(b,2)+newbox(b,2);
        Bubbles(b,5)=atan(Bubbles(b,5)/Bubbles(b,6))/2;
        d.Value = evalimage/data.no_images;
        d.Message = 'Run shape regression CNN';
        hold on;
        y=plotellipse(Bubbles(b,1:2),Bubbles(b,3),Bubbles(b,4),Bubbles(b,5));
        y.LineWidth=3;
        y.Color='red';
        %y.LineStyle=':'
        hold on;
        plot(Bubbles(b,1),Bubbles(b,2),'+','MarkerSize',10);

        
    end
   % delete (fh)
    detectedellipses{evalimage}=Bubbles(:,1:5);
end
delete (f)
save('Detectionresults.mat','detectedellipses');