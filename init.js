const cachedCoordinatesJson = localStorage.getItem("cachedCoordinates");
const cachedCoordinates = cachedCoordinatesJson ? JSON.parse(cachedCoordinatesJson) : [];

var app = Elm.Main.init({
  node: document.getElementById("elm-node"),
  flags: cachedCoordinates,
});

var map = null;
var markersGroup = null;

app.ports.setCachedCoordinates.subscribe(function (cachedCoordinates) {
  localStorage.setItem("cachedCoordinates", JSON.stringify(cachedCoordinates));
});

app.ports.initMap.subscribe(function (headquarter) {
  setTimeout(function () {
    map = L.map("map", { scrollWheelZoom: false }).setView([headquarter.latitude, headquarter.longitude], 17);
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map);
  }, 60);
});

app.ports.clearMap.subscribe(function () {
  if(map) {
    map.off()
    map.remove()
  }
});

app.ports.initRenderRouteMaps.subscribe(function (values) {
  const headquarter = values[0];
  const deliveriesByClusterAndSlot = values[1];

  const renderSlotClusterMap = (slot, cluster, deliveries) => {
    const headquarterMarker = L.marker([headquarter.latitude, headquarter.longitude]);
    const mapKey = "map-" + slot.replaceAll(' ', '') + "-cluster-" + cluster
    console.log("init map with key: " + mapKey)
    console.log("cluster: ", cluster)
    console.log("deliveries: ", deliveries)
    const slotClusterMap = L.map(mapKey, {scrollWheelZoom: false});

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(slotClusterMap);

    const deliveryMarkers = deliveries.map((delivery) => {
      const id = delivery[0]
      const coordinates = delivery[1]

      const icon = L.divIcon({ className: "marker " + "cluster-" + cluster, html: id });

      return L.marker([coordinates.latitude, coordinates.longitude], { icon: icon });
    });

    const markers = [headquarterMarker].concat(deliveryMarkers);
    markersGroup = new L.featureGroup(markers);
    markersGroup.addTo(slotClusterMap);

    slotClusterMap.fitBounds(markersGroup.getBounds().pad(0.1));
  };

  setTimeout(function () {
    deliveriesByClusterAndSlot.map((slotDeliveries) => {
      const slot = slotDeliveries[0];
      const deliveriesByCluster = slotDeliveries[1];

      deliveriesByCluster.map((clusterDeliveries) => {
        const cluster = clusterDeliveries[0];
        const deliveries = clusterDeliveries[1];

        renderSlotClusterMap(slot, cluster, deliveries);
      });
    });
  }, 60);
});

app.ports.addMarkers.subscribe(function (values) {
  const mode = values[0];
  const headquarter = values[1];
  const deliveries = values[2];

  const headquarterMarker = L.marker([headquarter.latitude, headquarter.longitude]);

  const deliveryMarkers = deliveries.map((delivery) => {
    const id = delivery[0];
    const coordinates = delivery[1];
    const cluster = delivery[2];

    const icon = L.divIcon({ className: "marker " + "cluster-" + cluster, html: id });
    const marker = L.marker([coordinates.latitude, coordinates.longitude], { icon: icon });

    marker.on("click", (_) => {
      app.ports.markerClicked.send(id);
    });

    return marker;
  });

  if (markersGroup) {
    markersGroup.clearLayers();
  }

  const markers = [headquarterMarker].concat(deliveryMarkers);
  markersGroup = new L.featureGroup(markers);
  markersGroup.addTo(map);

  if (mode === "initial") {
    map.fitBounds(markersGroup.getBounds().pad(0.1));
  }
});
