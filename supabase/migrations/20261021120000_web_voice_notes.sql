-- Voice notes recorded in a browser: WAV (what every phone and browser
-- plays; a browser's own WebM won't play on an iPhone), at 16 kHz mono,
-- about 960 KB for the 30 seconds a note can last. The apps' AAC stays as
-- it was.
update storage.buckets
   set allowed_mime_types = array['audio/mp4', 'audio/m4a', 'audio/aac', 'audio/x-m4a',
                                  'audio/wav', 'audio/x-wav', 'audio/wave'],
       file_size_limit = 1572864
 where id = 'voice-notes';
