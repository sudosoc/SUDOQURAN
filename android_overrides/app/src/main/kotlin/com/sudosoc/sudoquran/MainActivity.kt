package com.sudosoc.sudoquran

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps the Flutter engine shared with the background
// audio service, so playback survives leaving the app.
class MainActivity : AudioServiceActivity()
