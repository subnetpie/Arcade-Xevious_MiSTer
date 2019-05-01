---------------------------------------------------------------------------------
-- 
-- Arcade: Xevious port to MiSTer by Sorgelig
-- 23 October 2017
-- 
-- Revised: 
-- 1 May 2019
---------------------------------------------------------------------------------
-- Xevious by Dar (darfpga@aol.fr) (01 May 2017)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- gen_ram.vhd
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- T80/T80se - Version : 0247
-----------------------------
-- Z80 compatible microprocessor core
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
---------------------------------------------------------------------------------
-- 
-- Support screen and controls rotation on HDMI output.
-- Only controls are rotated on VGA output.
-- 
-- Keyboard inputs :
--
--   F1, 1                     : Start 1 player
--   F2, 2                     : Start 2 players
--   F3, 5, 6                  : Add coin
--   UP,DOWN,LEFT,RIGHT arrows : Movements
--   SPACE                     : Fire  
--   CTRL                      : Bomb
--   P                         : Pause
--
--   Joystick support.
-- 
---------------------------------------------------------------------------------
-- 
-- This port from http://darfpga.blogspot.fr has partial implementation of 
-- Namco custom chips which leads to limitations such as the following:
-- 
--   • Cocktail mode is not functioning properly.
--   • Coin logic is hard coded to 1 coin / 1 credit.
--   • Errors when loading Super Xevious or Super Xevious Plus.
-- 
-- Super Xevious and Super Xevious Plus do work but require pause
-- to be pressed at startup. Credits will be FF and controls will not
-- work. Right arrow will start a two player game and after game overs
-- everything will start to work properly.
--  
---------------------------------------------------------------------------------

                                *** Attention ***

ROM is not included. In order to use this arcade, you need to provide a correct ROM file.

Find this zip file somewhere. You need to find the file exactly as required.
Do not rename other zip files even if they also represent the same game - they are not compatible!
The name of zip is taken from M.A.M.E. project, so you can get more info about
hashes and contained files there.

To generate the ROM using Windows:
1) Copy the zip into "releases" directory
2) Execute bat file - it will show the name of zip file containing required files.
3) Put required zip into the same directory and execute the bat again.
4) If everything will go without errors or warnings, then you will get the a.*.rom file.
5) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file

To generate the ROM using Linux/MacOS:
1) Copy the zip into "releases" directory
2) Execute build_rom.sh
3) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file

To generate the ROM using MiSTer:
1) scp "releases" directory along with the zip file onto MiSTer:/media/fat/
2) Using OSD execute build_rom.sh
3) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file