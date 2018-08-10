# Invisible Map Project
The Invisible Map Project is intended to assist the blind and visually impaired more easily navigate indoor spaces. We utilize april tags and the pose of an iPhone to localize the person in a three dimensional map of their surrounding environment and help them navigate.

Built for OccamLab @Olin College 2018

## Running the app
(1) After cloning this repository as InvisibleMap, go to http://visp-doc.inria.fr/download/snapshot/ios/ and download and unzip the latest version of the visp3 framework.

(2) In Finder, drag the `opencv2.framework` and `visp3.framework` frameworks into your local InvisibleMap folder.

(3) You will need to contact a member of OccamLab in order to be added to the Firebase console project to get the `GoogleService-Info.plist` file. Once you have this file, copy it into your `InvisibleMap/InvisibleMap` folder.

(4) In your terminal, run `open InvisibleMap.xcworkspace/`.

(5) Build and run the app!

To learn more about OccamLab, please visit our website: http://occam.olin.edu/.
