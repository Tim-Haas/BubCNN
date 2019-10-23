classdef maeRegressionLayer < nnet.layer.RegressionLayer
        %MAE Regression Layer
    properties
        % (Optional) Layer properties.

        % Layer properties go here.
    end
 
    methods
        function layer = maeRegressionLayer(name)           
            % (Optional) Create a myRegressionLayer.

            % Layer constructor function goes here.
        end

        function loss = forwardLoss(layer, Y, T)
            % loss = forwardLoss(layer, Y, T) returns the MAE loss between
            % the predictions Y and the training targets T.

            % Calculate MAE.
            R = size(Y,3);
            meanAbsoluteError = sum(abs(Y-T),3)/R;
    
            % Take mean over mini-batch.
            N = size(Y,4);
            loss = sum(meanAbsoluteError)/N;
        end
        
        function dLdY = backwardLoss(layer, Y, T)

            R = size(Y,3);
            N = size(Y,4);
            dLdY = sign(Y-T)/(N*R);
        end
    end
end
