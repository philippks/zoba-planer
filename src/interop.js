// This returns the flags passed into your Elm application
export const flags = async ({ env }) => {
  const cachedCoordinatesJson = localStorage.getItem("cachedCoordinates");
  let cachedCoordinates = [];
  
  try {
    cachedCoordinates = cachedCoordinatesJson ? JSON.parse(cachedCoordinatesJson) : [];
  } catch (error) {
    console.warn("Failed to parse cached coordinates from localStorage:", error);
    cachedCoordinates = [];
  }
  
  return {
    cachedCoordinates: cachedCoordinates
  }
}

// Global variables for map management
var map = null;
var markersGroup = null;

// This function is called once your Elm app is running
export const onReady = ({ app, env }) => {
  console.log('Elm Land is ready', app)
  
  // Set up port subscriptions if they exist
  if (app.ports && app.ports.setCachedCoordinates) {
    app.ports.setCachedCoordinates.subscribe(function (cachedCoordinates) {
      localStorage.setItem("cachedCoordinates", JSON.stringify(cachedCoordinates));
    });
  }

  if (app.ports && app.ports.initMap) {
    app.ports.initMap.subscribe(function (headquarter) {
      // Small delay to ensure DOM element is available
      // Leaflet needs the target div to exist in the DOM before initialization
      setTimeout(function () {
        map = L.map("map", { scrollWheelZoom: false }).setView([headquarter.latitude, headquarter.longitude], 17);
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
          maxZoom: 19,
          attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        }).addTo(map);
      }, 60);
    });
  }

  if (app.ports && app.ports.clearMap) {
    app.ports.clearMap.subscribe(function () {
      if (map) {
        map.off();
        map.remove();
        map = null;
      }
    });
  }

  if (app.ports && app.ports.initRenderRouteMaps) {
    app.ports.initRenderRouteMaps.subscribe(function (values) {
      const headquarter = values[0];
      const deliveriesByClusterAndSlot = values[1];

      const renderSlotClusterMap = (slot, cluster, deliveries) => {
        const headquarterMarker = L.marker([headquarter.latitude, headquarter.longitude]);
        const mapKey = "map-" + slot.replaceAll(" ", "") + "-cluster-" + cluster;
        console.log("init map with key: " + mapKey);
        console.log("cluster: ", cluster);
        console.log("deliveries: ", deliveries);
        const slotClusterMap = L.map(mapKey, { scrollWheelZoom: false });

        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
          attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        }).addTo(slotClusterMap);

        const deliveryMarkers = deliveries.map((delivery) => {
          const id = delivery[0];
          const coordinates = delivery[1];

          const icon = L.divIcon({ className: "marker " + "cluster-" + cluster, html: id });

          return L.marker([coordinates.latitude, coordinates.longitude], { icon: icon });
        });

        const markers = [headquarterMarker].concat(deliveryMarkers);
        markersGroup = new L.featureGroup(markers);
        markersGroup.addTo(slotClusterMap);

        slotClusterMap.fitBounds(markersGroup.getBounds().pad(0.1));
      };

      // Small delay to ensure DOM elements are available for multiple maps
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
  }

  if (app.ports && app.ports.addMarkers) {
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
          if (app.ports && app.ports.markerClicked) {
            app.ports.markerClicked.send(id);
          }
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
  }
}