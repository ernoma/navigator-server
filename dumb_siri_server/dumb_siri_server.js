var net = require('net');
var fs = require('fs');
var et = require('elementtree');

var server = net.createServer(function (c) {
  console.log('connected');
  c.setEncoding('utf8');
  //c.setNoDelay(true);
  c.on('data', function(data) {
    console.log(data);
    fs.writeFile("request.xml", data, function(err) {
      //TODO
    });
    
    //var dummy_resp_data = fs.readFileSync("siri_vm_vastaus_kaikki_ajoneuvot.xml", {"encoding": "utf8"});
    var dummy_resp_data = fs.readFileSync("siri_vm_vastaus_kaikki_ajoneuvot.xml").toString();
    var etree = et.parse(dummy_resp_data);
    
    var response = etree.write({'xml_declaration': false});
    //console.log(response);
    c.write(response);
  });
  
  //c.write('hello\n');
  
  //c.pipe(c);
});

server.listen(1337, '127.0.0.1');

console.log('Server running at http://127.0.0.1:1337/');

