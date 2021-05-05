function houghAccumulator()

output_folder_name = '../processed_images/hough';

% Create the output folder if it doesn't exist
if ~exist(output_folder_name, 'dir')
   mkdir(output_folder_name)
end
% input_folder_name = '../processed_images/edges';
% 
im_name = '/image-1.png';
% % Read the image.
% input_img_name = strcat(input_folder_name,im_name);
% img = imread(input_img_name);
% 
% 
% [y,x] = size(img);
shrink_factor = 4;
% acc_size = round(x/shrink_factor);
radius_start = 20/shrink_factor;
% radius_len = 12/shrink_factor;
% % init the accumulator
% acc = zeros(acc_size, acc_size,radius_len);
% 
% % Run through each pixel in the image
% for i = 1:y
%     for j = 1:x
%         if img(i,j) > 0 %The pixel is part of an edge.
%             for r = 1:radius_len
%                 holder=[];
%                 % Lots of duplicate a,b values due to reduced accumulator
%                 % mean that we can reduce the number of points we draw. 256
%                 % fits nicely into a cuda kernel.
%                 % for t = linspace(1,360,256) % Draw each circle in the accumulator space
%                 shrunk_i = i/shrink_factor;
%                 shrunk_j = j/shrink_factor;
%                 for t = 1:360
%                     sin_result = sin(t*pi/180);
%                     cos_result = cos(t*pi/180);                
%                     r_a = radius_start+r;
%                     a = round(shrunk_i-r_a*sin_result);
%                     b = round(shrunk_j-r_a*cos_result);
%                     holder = [holder; [a,b]];
%                     % Gotta be within the range
%                     if 0 < a && a <= acc_size && 0 < b && b<=acc_size
%                         % Increment the value in the accumulator.
%                         acc(a,b,r) = acc(a,b,r) + 1; 
%                     end
%                 end
% %                 [temp,~,ix] = unique(holder(:,1:2),'rows');
% %                 ix = accumarray(ix,1);
% %                 temp = [temp,ix];
%                 breakpoint = 0;
%             end
%         end
%     end
% end
% 
% % To write the accumulator as an image, scale all values to be
% % between 0 and 255. Set max value in accumulator==255
% acc = rescale(acc,0,255);
% for z = 1:radius_len
%     % Write accumulator as an image
%     output_img_name = strcat(output_folder_name,'/image-1_',num2str(z),'.png');
%     imwrite(uint8(acc(:,:,z)), output_img_name);
% end


file = fopen('../processed_images/hough/binary/image-1-out');
cuda_acc_1 = fread(file,[64,64], 'int32');
cuda_acc_2 = fread(file,[64,64], 'int32');
cuda_acc_3 = fread(file,[64,64], 'int32');
fclose(file);

acc = cat(3,cuda_acc_1,cuda_acc_2,cuda_acc_3);

% acc = rescale(cuda_acc,0,255);
% for z = 1:3
%      % Write accumulator as an image
%     output_img_name = strcat(output_folder_name,'/cuda_image-1_',num2str(z),'.png');
%     imwrite(uint8(cuda_acc(:,:,z)), output_img_name);
% end





%Threshold at which we consider a point the center of a circle
%threshold = 200;
threshold = max(max(max(acc))) - 1.5 * mean(mean(mean(acc(acc>0))));

[hough_y, hough_x, hough_z] = size(acc);

% Find all centers that pass threshold
% Store each line as a,b
circles = zeros(0,3);
for i = 1:hough_y
    for j = 1:hough_x
        for k = 1:hough_z
            if acc(i,j,k) >= threshold
                circles = [circles; [j*shrink_factor-1,i*shrink_factor-1,(k+radius_start)*shrink_factor]];
            end
        end
    end 
end

circles_sorted = sortrows(circles,[1,2]);
% Average circles that are basically the same.
% This isn't needed but reduces noise significantly.
circles_filtered = zeros(0,3);
prev_circle = circles_sorted(1,:);
sum_x = prev_circle(1);
sum_y = prev_circle(2);
sum_r = prev_circle(3);
counter = 1;
max_offset = 10;
for i = 2:size(circles_sorted)
    cur_circle = circles_sorted(i,:);
    if abs(cur_circle(1)-prev_circle(1)) < max_offset && abs(cur_circle(2) - prev_circle(2))<max_offset
        sum_x = sum_x + cur_circle(1);
        sum_y = sum_y + cur_circle(2);
        sum_r = sum_r + cur_circle(3);
        counter = counter + 1;
        prev_circle = cur_circle;
    else
        circles_filtered = [circles_filtered; [sum_x/counter, sum_y/counter, sum_r/counter]];
        sum_x = cur_circle(1);
        sum_y = cur_circle(2);
        sum_r = cur_circle(3);
        counter = 1;
        prev_circle = cur_circle;
    end
    % Ensure the last line/lines average gets added
    if i == size(circles_sorted,1)
        circles_filtered = [circles_filtered; [sum_x/counter, sum_y/counter, sum_r/counter]];
    end
end

circles = circles_filtered;

% Create figure and show the image so that we can draw lines on top of it.
fh = figure();
figure(fh);
imshow(imread(strcat('../images',im_name)));
hold on;
th = 0:pi/50:2*pi;
for i = 1:size(circles)
    x = circles(i,1);
    y = circles(i,2);
    r = circles(i,3);
    xunit = r * cos(th) + x;
    yunit = r * sin(th) + y;
    plot(xunit, yunit,'r-','LineWidth',3);
end
hold off;
% Save the image with the lines drawn on it.
circle_detected_img = saveAnnotatedImg(fh);
delete(fh);

imwrite(uint8(circle_detected_img),'../output/bloodcells/image-1.png');

% fh = figure();
% subplot(2,2,1)
% imshow(imread(strcat('../images', im_name)));
% subplot(2,2,2)
% imshow(imread(strcat('../processed_images/edges',im_name)));
% % subplot(2,2,3)
% % imshow(im2double(uint8(acc)));
% subplot(2,2,4)
% imshow(circle_detected_img);

end

function annotated_img = saveAnnotatedImg(fh)
figure(fh); % Shift the focus back to the figure fh

% The figure needs to be undocked
set(fh, 'WindowStyle', 'normal');

% The following two lines just to make the figure true size to the
% displayed image. The reason will become clear later.
img = getimage(fh);
truesize(fh, [size(img, 1), size(img, 2)]);

% getframe does a screen capture of the figure window, as a result, the
% displayed figure has to be in true size. 
frame = getframe(fh);
frame = getframe(fh);
pause(0.5); 
% Because getframe tries to perform a screen capture. it somehow 
% has some platform depend issues. we should calling
% getframe twice in a row and adding a pause afterwards make getframe work
% as expected. This is just a walkaround. 
annotated_img = frame.cdata;
end

