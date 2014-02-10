bat
===

Characters Recognition on Bat Skulls
------------------------------------

This code is used for building the part based model for localizing parts in a bat skull image. The code is built based on the PartBasedDetector project (https://github.com/wg-perception/PartsBasedDetector) and Yi Yang's code for [1]. Within the context of AVATOL project, the parts are skull parts, e.g. teeth and nasal. This version focuses on localizing characters, i.e. presence or absense. Sequential characters recognition could be further developed based on the predicted locations of parts in the image.

	[1] Yi Yang, Deva Ramanan, "Articulated Pose Estimation with Flexible Mixtures-of-Parts," CVPR 2011

How to use the code
-------------------
The system basically includes 2 main conponents: training and testing. Please follow the steps below to learn the models for each species. NOTE that current code is mainly used for localization, so the size of parts are the same in the model. 

 - Open Matlab and setup Mex if neccessary (type "mex -setup" and follow the instructions).
 - Run compile.m (type "compile" in Matlab) to compile the required mex files. 
 - Run demo3.m to see how to annotate, train and test with the part based model. The data of species Artibeus is supplied.

 OR

 - Annotate your training data. A simple utility util/annotateParts.m is provided. User need to click on the center of each tooth. 
 - Run demo.m (for Artibeus).


