-- Paths and stuff
set ArtworkFromiTunes to ((path to home folder) as text) & ¬
  "Pictures:iTunes Artwork:From iTunes:albumArt.tif" as alias
set iTunesArtwork to ((path to home folder) as text) & ¬
  "Pictures:iTunes Artwork:From iTunes:albumArt.tif"
set DefaultArtwork to ((path to home folder) as text) & ¬
  "Pictures:iTunes Artwork:Default:albumArt.tif"
set displayArtwork to ((path to home folder) as text) & ¬
  "Pictures:iTunes Artwork:albumArt.tif"

-- Unix versions of the above path strings
set unixITunesArtwork to the quoted form of POSIX path of iTunesArtwork
set unixDefaultArtwork to the quoted form of POSIX path of DefaultArtwork
set unixDisplayArtwork to the quoted form of POSIX path of displayArtwork

set whichArt to "blank"
tell application "System Events"
  if exists process "iTunes" then -- iTunes is running
    tell application "iTunes"
      if player state is playing then -- iTunes is playing
        set aLibrary to name of current playlist -- Name of Current Playlist
        set aTrack to current track
        set aTrackArtwork to null
        if (count of artwork of aTrack) ≥ 1 then -- there's an album cover
          "Running and playing and art"
          set aTrackArtwork to data of artwork 1 of aTrack
          set fileRef to ¬
            (open for access ArtworkFromiTunes with write permission)
          try
            set eof fileRef to 512
            write aTrackArtwork to fileRef starting at 513
            close access fileRef
          on error errorMsg
            try
              close access fileRef
            end try
            error errorMsg
          end try

          tell application "Finder" to ¬ 
            set creator type of ArtworkFromiTunes to "????"
          set whichArt to "iTunes"
        end if
      end if
    end tell
  end if
end tell

if whichArt is "iTunes" then
  do shell script "ditto -rsrc " & unixITunesArtwork & space & unixDisplayArtwork
else
  do shell script "ditto -rsrc " & unixDefaultArtwork & space & unixDisplayArtwork
end if
