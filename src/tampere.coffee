net = require 'net'
moment = require 'moment'
et = require 'elementtree'
XML = et.XML;
ElementTree = et.ElementTree;
element = et.Element;
subElement = et.SubElement;

receivedData = "";

fs = require 'fs'

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
        # Connect to HSL Live server via PUSH interface
        @client = net.connect 1337, 'localhost' 
        @client.on 'connect', (conn) =>
            console.log "TampereClient connected"
            #console.log @.requestAllVehicles()
            @client.write @.requestAllVehicles()

        line_handler = (line) =>
            @.handle_line line

        @client.on 'data', (data) ->
          line_handler data.toString()

    # handle_line function creates out_info objects of the lines received from carrier
    # and calls @callback to handle the created out_info objects. The out_info object
    # format should be same as for the manchester.coffee.
    handle_line: (line) ->
        #console.log "Received line " + line
        receivedData += line
        if receivedData.indexOf("</Siri>") != -1
            #fs.writeFile "response.xml", receivedData, (err) ->
            etree = et.parse receivedData
            
            #VehicleRef / FramedVehicleJourneyRef.DatedVehicleJourneyRef == vehicle.id
            #VehicleRef / OriginName-DestinationName == vehicle.label
            #LineRef == trip.route
            #DirectionRef == trip.direction
            #VehicleLocation.Latitude == position.latitude
            #VehicleLocation.Longitude == position.longitude
            #Bearing = position.bearing
            #RecordedAtTime in unix_epoch_gps_time / 1000 == timestamp
            
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
            
            receivedData = ""
            

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
        requestTimestamp.text = 
        requestorRef = subElement serviceRequest, 'RequestorRef'
        requestorRef.text = "CITYNAVI" # TODO use real ParticipantCode as RequestorRef
        vehicleMonitoringRequest = subElement serviceRequest, 'VehicleMonitoringRequest'
        vehicleMonitoringRequest.set 'version', '1.3'
        vrequestTimestamp = subElement vehicleMonitoringRequest, 'RequestTimestamp'
        vrequestTimestamp.text = date
        vehicleMonitoringRef = subElement vehicleMonitoringRequest, 'VehicleMonitoringRef'
        vehicleMonitoringRef.text = "VEHICLES_ALL"
        
        etree = new ElementTree root
        
        return etree.write {'xml_declaration': true}
        

module.exports.TampereClient = TampereClient # make TampereClient visible in server.coffee
