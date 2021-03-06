//
// | (• ◡•)| (❍ᴥ❍ʋ)

let app, node;

node = document.getElementById("elm-container");
node.innerHTML = "";

app = Elm.App.embed(node);



//
// > Audio

const audioEnvironmentContext = {
  activeQueueItem: null,
  elm: app,
  repeat: false
};

app.ports.activeQueueItemChanged.subscribe(item => {
  const timestampInMilliseconds = Date.now();

  audioEnvironmentContext.activeQueueItem = item;
  audioEnvironmentContext.audio = null;

  removeOlderAudioElements(timestampInMilliseconds);

  if (item) {
    insertTrack(audioEnvironmentContext, item);
  } else {
    app.ports.setIsPlaying.send(false);
    setProgressBarWidth(0);
  }
});

app.ports.requestPlay.subscribe(_ => {
  if (audioEnvironmentContext.audio) {
    audioEnvironmentContext.audio.play();
  }
});

app.ports.requestPause.subscribe(_ => {
  if (audioEnvironmentContext.audio) {
    audioEnvironmentContext.audio.pause();
  }
});

app.ports.requestSeek.subscribe(percentage => {
  const audio = audioEnvironmentContext.audio;

  if (audio && !isNaN(audio.duration)) {
    audio.currentTime = audio.duration * percentage;
    if (audio.paused) audio.pause();
  }
});



//
// > Equalizer

app.ports.adjustEqualizerSetting.subscribe(e => {
  let node;

  switch (e.knob) {
    case "Low"      : node = low; break;
    case "Mid"      : node = mid; break;
    case "High"     : node = high; break;
    case "Volume"   : node = volume; break;
  }

  node.gain.value = determineNodeGainValue(e.knob, e.value);
});



//
// > Processing

app.ports.requestTags.subscribe(distantContext => {
  const context = Object.assign({}, distantContext);
  const initialPromise = Promise.resolve([]);

  return context.urlsForTags.reduce((accumulator, urls) => {
    return accumulator.then(col =>
      getTags(urls.getUrl, urls.headUrl)
        .then(r => col.concat(r))
        .catch(e => {
          console.error(e);
          return col.concat(null);
        })
    );

  }, initialPromise).then(col => {
    context.receivedTags = _.compose(
      x => _.map(pickTags, x),
      x => _.filter(_.isObject, x)
    )(
      col
    );

    app.ports.receiveTags.send(context);

  });
});



//
// > Queue

app.ports.toggleRepeat.subscribe(bool => {
  audioEnvironmentContext.repeat = bool;
});



//
// > Search

const search = new Worker("/workers/search.js");

app.ports.performSearch.subscribe(searchTerm => {
  search.postMessage({
    action: "perform_search",
    data: searchTerm
  });
});

app.ports.updateSearchIndex.subscribe(tracksJSON => {
  search.postMessage({
    action: "update_search_index",
    data: tracksJSON
  });
});

search.onmessage = event => {
  switch (event.data.action) {
    case "perform_search":
      app.ports.receiveSearchResults.send(event.data.data);
      break;
  }
};



//
// > Touch devices

window.addEventListener("touchstart", function onFirstTouch() {
  app.ports.setIsTouchDevice.send(true);
  window.removeEventListener("touchstart", onFirstTouch, false);
});
