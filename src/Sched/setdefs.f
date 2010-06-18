      SUBROUTINE SETDEFS
C
C     Routine for SCHED, called by DEFSET, which in turn is called
C     by DEFAULTS.  At this point, all setup files have been read.
C     This routine sets many setup file defaults.  Much use
C     is made of information from the station and frequency catalogs. 
C
      INCLUDE   'sched.inc'
      INCLUDE   'schset.inc'
      INCLUDE   'schfreq.inc'
C
      INTEGER    KS, ISETF, I, ICH
      LOGICAL    NEEDCAT(MSET)
C ---------------------------------------------------------------------
      IF( SDEBUG ) CALL WLOG( 0, 'SETDEFS: Starting' )
C
C     Deal with the VLA phasing mode flags in the setup groups.
C     The results are needed in SETFCAT.
C
      CALL VLAPMODE
C
C     Now begin the real work.  First set the global parameters
C     that are station independent and should match across stations.  
C     But for the moment, don't attempt to check that they do match.
C     Some checking is done in CHKSFIL.
C     These are: 
C     FREQREF   LO sum for channel.
C     BBFILT    Bandwidth for channel
C     SAMPRATE  Sample rate for channel
C     NCHAN     Number of baseband channels
C     BITS      Bits per sample
C     POL       Polarazition of each channel
C     NETSIDE   Net sideband of each channel
C     SPEEDUP   Processing speedup factor.
C
C     Set the contents of the baseband channels.
C
C     First determine the resources available and requested.
C
C     Determine the minimum number of BBC's available at the 
C     stations that use each setup file (MINBBC).  Also get
C     the maximum number of channels requested for each setup file.
C
      DO ISETF = 1, NSETF
         MSCHN(ISETF)  = 0
         MINBBC(ISETF) = 99
      END DO
      DO KS = 1, NSET
         ISETF = ISETNUM(KS)
         MSCHN(ISETF) = MAX( MSCHN(ISETF), NCHAN(KS) )
         MINBBC(ISETF) =  MIN( MINBBC(ISETF), NBBC(ISETSTA(KS)) )
      END DO
C
C     Try to set many defaults.  For now, don't attempt to do so
C     for VLA-only observations.
C
      IF( .NOT. VLAONLY ) THEN
         DO KS = 1, NSET
C
C           Apply defaults for polarization, samplerate and
C           sidebands as required.  This is hardware independent
C           stuff.
C
            CALL SETCHAN( KS )
C
C           Set the frequencies based on the various inputs.
C
            CALL SETFREQ( KS, NEEDCAT(KS) )
C
C           Now the generic channel information is mostly known
C           although the polarization might not be known until
C           after the frequency catalog is read, if IFCHANs 
C           were specified in the setup.  Perhaps this should not
C           be allowed.  I don't think it is done.
C
C           Set some hardware dependent items that need to be set
C           from setup file data before the station dependent 
C           default data is gathered from the frequency catalog.  
C           The IFCHANS are one such item.
C
            CALL SETHW1( KS )
C
         END DO
C
C        Now that we have the FREQSET and NETSIDE, we can 
C        identify the proper frequency catalog entry.  Do so 
C        and extract any information available in the frequency 
C        catalog that is needed.  Of course, much of this is 
C        station hardware dependent.
C
         DO KS = 1, NSET
            CALL SETFCAT( KS, NEEDCAT(KS) )
         END DO
C
C        Make the BBC assignments based on the channel contents
C        and the DAR and RECORDER types.  
C
         DO KS = 1, NSET
            CALL SETBBC( KS )
         END DO
C
C        Now everything except formatting and recording details
C        are set.
C
C        Set the recorder information including FORMAT etc.
C
         CALL SETREC
C
C        Set the default track assignments for wide band modes.
C
         DO KS = 1, NSET
            IF( TRACK(1,1,KS) .EQ. 0 .AND.
     1        ( FORMAT(KS)(1:4) .EQ. 'VLBA' .OR.
     2          FORMAT(KS)(1:4) .EQ. 'MKIV' .OR.
     3          FORMAT(KS) .EQ. 'MARKIII' ) ) THEN
C
               CALL SETTRK( NCHAN(KS), TAPEMODE(KS), FORMAT(KS), 
     1               BITS(1,KS), TRACK(1,1,KS), MCHAN, BBC(1,KS), 
     2               SIDEBD(1,KS), KS, TWOHEAD, DEBUG, ILOG )
C
            ELSE IF( TRACK(1,1,KS) .EQ. 0 .AND.
     1        FORMAT(KS)(1:6) .EQ. 'MARK5B' ) THEN
               IF( BITS(1,KS) .EQ. 2 ) THEN
                  DO ICH = 1, NCHAN(KS)
                     TRACK(ICH,1,KS) = 2*ICH
                  END DO
               ELSE
                  DO ICH = 1, NCHAN(KS)
                     TRACK(ICH,1,KS) = ICH + 1
                  END DO
               END IF
            END IF
         END DO
C
C        Set unspecified synthesizers to 15.4 for most bands.
C        Set to 10.9 GHz for 2 cm observations to keep them out
C        of the RF.  This is for the VLBA.
C     
         DO KS = 1, NSET
            DO I = 1, 3
               IF( SYNTH(I,KS) .EQ. 0.0 ) THEN
                  IF( FE(2,KS) .EQ. '2cm' .OR.
     1                FE(4,KS) .EQ. '2cm' ) THEN
                     SYNTH(I,KS) = 10.9
                  ELSE
                     SYNTH(I,KS) = 15.4
                  END IF
               END IF
            END DO
         END DO
C
      END IF
C
      RETURN
      END


