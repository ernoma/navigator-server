request = require 'request'
http = require 'http'
moment = require 'moment'
et = require 'elementtree'
XML = et.XML;
ElementTree = et.ElementTree;
element = et.Element;
subElement = et.SubElement;

receivedData = "";

fs = require 'fs'

sirihost = require './sirihost.js'

http_request_options = 
    url: "http://" + sirihost.serverhost + ":" + sirihost.serverport + '/siriaccess/vm/rest'
    method: 'GET'

# make vehicleMonitoringSubscriptionRequest with VehicleMonitoringDetailLevel=basic
# see http://www.kizoom.com/standards/siri/schema/1.0/examples/exv_vehicleMonitoring_subscriptionRequest.xml and SIRI Handbook, chapter 6 "SIRI Vehcile Monitoring (VM)
# with more detail level could maybe remove busses from the map that are returning to carage, etc. ->
# more user friendly
# SIRI JSON? 

# TampereClient connects to OneBusAway SIRI repeater (Realtime API of vehicle locations)
# on ITS Factory Data Platform and
# converts the received real-time SIRI XML data to the format used by city-navigator clients.
# TampereClient uses @callback function (defined in server.coffee) to publish the data
# to the clients.
class TampereClient    
    constructor: (@callback, @args) ->

    connect: ->
        setInterval @get_data, 1000, @handle_data, @callback
    
    get_data: (handle_data, callback) ->
        request http_request_options, (err, res, data) ->
            #console.log err
            #console.log 'status code: ' + res.statusCode.toString()
            #console.log 'headers: ' + JSON.stringify(res.headers)
            #console.log 'body: ' + data + "\n"
            if !err and res.statusCode is 200
                handle_data JSON.parse(data), callback
    
    # handle_data function creates out_info objects of the data received from siri server
    # and calls @callback to handle the created out_info objects. The out_info object
    # format should be same as for the manchester.coffee.
    handle_data: (data, callback) ->
        #console.log JSON.stringify(data)
        #console.log data.Siri.ServiceDelivery.VehicleMonitoringDelivery
        for VehicleMonitoringDelivery in data.Siri.ServiceDelivery.VehicleMonitoringDelivery
            #console.log "VehicleMonitoringDelivery" + JSON.stringify(VehicleMonitoringDelivery) + "\n"
            for VehicleActivity in VehicleMonitoringDelivery.VehicleActivity
                #console.log "VehicleActivity" + JSON.stringify(VehicleActivity) + "\n"
                MonitoredVehicleJourney = VehicleActivity.MonitoredVehicleJourney
                #console.log "MonitoredVehicleJourney" + MonitoredVehicleJourney + "\n"

                out_info =
                    vehicle:
                        id: MonitoredVehicleJourney.VehicleRef.value
                        label: MonitoredVehicleJourney.OriginName.value
                    trip:
                        route: MonitoredVehicleJourney.LineRef.value
                        direction: MonitoredVehicleJourney.DirectionRef.value
                    position:
                        latitude: MonitoredVehicleJourney.VehicleLocation.Latitude
                        longitude: MonitoredVehicleJourney.VehicleLocation.Longitude
                        bearing: MonitoredVehicleJourney.Bearing
                    timestamp: VehicleActivity.RecordedAtTime
                    
                path = "/location/tampere/#{out_info.trip.route}/#{out_info.vehicle.id}"
                callback path, out_info, @args
            
    handle_xml_data: (data) ->
        etree = et.parse data
        #console.log etree
        vehicleActivities = etree.findall './/VehicleActivity'
        console.log vehicleActivities.length
        #console.log etree.findall('.//MonitoredVehicleJourney')
            
        for vehicleActivity in vehicleActivities
            monitoredVehicleJourney = vehicleActivity.find './MonitoredVehicleJourney'
            vehicle_id = monitoredVehicleJourney.find('./VehicleRef').text
            #console.log vehicle_id
            vehicle_label = monitoredVehicleJourney.find('./OriginName').text + "-" +
                monitoredVehicleJourney.find('./DestinationName').text
            trip_route = monitoredVehicleJourney.find('./LineRef').text
            trip_direction = monitoredVehicleJourney.find('./DirectionRef').text
            position_latitude = monitoredVehicleJourney.find('./VehicleLocation/Latitude').text
            position_longitude = monitoredVehicleJourney.find('./VehicleLocation/Longitude').text
            #console.log position_longitude1369715515011
            position_bearing = monitoredVehicleJourney.find('./Bearing').text
            recordedAtTime = vehicleActivity.find('./RecordedAtTime').text
            #console.log recordedAtTime
            date = Date.parse moment(recordedAtTime)
            #console.log date
            timestamp = date / 1000
            #console.log timestamp
                
            out_info =
                vehicle:
                    id: vehicle_id
                    label: vehicle_label
                trip:
                    route: trip_route
                    direction: trip_direction
                position:
                    latitude: parseFloat position_latitude
                    longitude: parseFloat position_longitude
                    bearing: parseFloat position_bearing
                timestamp: timestamp
                
            path = "/location/tampere/#{trip_route}/#{vehicle_id}"
            @callback path, out_info, @args

    addVehicleMonitoringRequest: (parentElement, date, vehicleMonitoringRefText) ->
        vehicleMonitoringRequest = subElement parentElement, 'VehicleMonitoringRequest'
        vehicleMonitoringRequest.set 'version', '1.3'
        vrequestTimestamp = subElement vehicleMonitoringRequest, 'RequestTimestamp'
        vrequestTimestamp.text = date
        vehicleMonitoringRef = subElement vehicleMonitoringRequest, 'VehicleMonitoringRef'
        vehicleMonitoringRef.text = vehicleMonitoringRefText

    requestAllVehicles: ->
    
        console.log "In requestAllVehicles"
        root = element 'Siri'
        root.set 'xmlns', 'http://www.siri.org.uk/siri'
        root.set 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance'
        root.set 'version', '1.3'
        root.set 'xsi:schemaLocation', 'http://www.kizoom.com/standards/siri/schema/1.3/siri.xsd'
        
        serviceRequest = subElement root, 'ServiceRequest'
        requestTimestamp = subElement serviceRequest, 'RequestTimestamp'
        date = moment().format()
        requestTimestamp.text = date
        requestorRef = subElement serviceRequest, 'RequestorRef'
        requestorRef.text = "CITYNAVI" # TODO use real ParticipantCode as RequestorRef
        
        @.addVehicleMonitoringRequest serviceRequest, date, "VEHICLES_ALL"
        
        etree = new ElementTree root
        
        return etree.write {'xml_declaration': true}
        
    subscribeAllVehicles: ->
        root = element 'Siri'
        root.set 'xmlns', 'http://www.siri.org.uk/siri'
        root.set 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance'
        root.set 'version', '1.3'
        root.set 'xsi:schemaLocation', 'http://www.kizoom.com/standards/siri/schema/1.3/siri.xsd'
      
        subscriptionRequest = subElement root, 'SubscriptionRequest'
        requestTimestamp = subElement subscriptionRequest, 'RequestTimestamp'
        date = moment().format()
        requestTimestamp.text = date
        requestorRef = subElement subscriptionRequest, 'RequestorRef'
        requestorRef.text = "CITYNAVI" # TODO use real ParticipantCode as RequestorRef

        vehicleMonitoringSubscriptionRequest =
            subElement subscriptionRequest, 'VehicleMonitoringSubscriptionRequest'
        subscriptionIdentifier =
            subElement vehicleMonitoringSubscriptionRequest, 'SubscriptionIdentifier'
        subscriptionIdentifier.text = "00000001" # TODO use real SubscriptionIdentifier
        initialTerminationTime =
            subElement vehicleMonitoringSubscriptionRequest, 'InitialTerminationTime'
        initialTerminationTime.text =
          moment().add('days', 365).format() #TODO use shorter terminaton time and renew the subscription
        
        @.addVehicleMonitoringRequest vehicleMonitoringSubscriptionRequest, date, "VEHICLES_ALL"
        
        incrementalUpdates =
            subElement vehicleMonitoringSubscriptionRequest, 'IncrementalUpdates'
        incrementalUpdates.text = "false" #TODO use true to optimize resource use
        updateInterval = subElement vehicleMonitoringSubscriptionRequest, 'UpdateInterval'
        updateInterval.text = "PT1S" # 1/s, see http://www.w3schools.com/schema/schema_dtypes_date.asp
        
        etree = new ElementTree root
        
        return etree.write {'xml_declaration': true}

module.exports.TampereClient = TampereClient # make TampereClient visible in server.coffeesubscriptionRequest
