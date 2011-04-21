package vkontakte.vk.api {
  
  import flash.net.*;
  import flash.errors.*;
  import flash.events.*;
  import flash.utils.Timer;
  import flash.events.TimerEvent;
  
  import vkontakte.vk.api.serialization.json.*;
  
  public class DataProvider {    
	private var _api_url: String = "http://api.vkontakte.ru/api.php";
	private var _api_sid: String;
    private var _api_id: Number;
	private var _api_test_mode: Number = 0;
    private var _api_secret: String;
    private var _viewer_id: Number;
    private var _request_params: Array;
    
    private var _global_options: Object;
    
	private var _mQueue : Array = [];
	
	private static const VK_REQUEST_DELAY:uint = 1100;// ограничение на запросы от одного экземпляра приложения в мс
	private static const VK_REQUEST_LIMIT:uint = 2;// ограничение на количество запросов в указанный интервал
	
	private var _timer:Timer;// таймер отправки запросов из очереди
	private var _lastRequestCount:uint = 0;
    
    public function DataProvider(api_url: String, api_id: Number, api_sid: String, api_secret: String, viewer_id: Number, api_test_mode: Number) {
	  _api_secret = api_secret;
	  _api_url	  = api_url;
	  _api_id     = api_id;
	  _api_sid    = api_sid;
	  if (api_test_mode) {
		  _api_test_mode  = api_test_mode;  
	  }
      _viewer_id  = viewer_id;
    }
    
    public function setup(options: Object): void {
      _global_options = options;
    }
    
    public function request(method: String, options: Object = null):void {
      var onComplete: Function, onError: Function;
      if (options == null) {
        options = new Object();
      }
      options.onComplete = options.onComplete ? options.onComplete : (_global_options.onComplete ? _global_options.onComplete : null);
      options.onError = options.onError ? options.onError : (_global_options.onError ? _global_options.onError : null);
	  var request:Object = {
		  'method' : method,
		  'options' : options,
		  'flag' : false
	  };
//	trace('------------------------------------------------------------------');
//	trace('REQUEST:     \nmethod - '+method+'\nparameters - ');
//	for (var y in options.params)
//	{
//		trace('     '+y + ': '+options.params[y]);
//	}
//	trace('------------------------------------------------------------------');
	if (!(_mQueue))
		_mQueue = [];
	
	_mQueue.push(request);
	_request();
    }
    
	private function _request():void
	{
		var length:int = VK_REQUEST_LIMIT - _lastRequestCount;
		if (length > _mQueue.length)
		{
			length = _mQueue.length;
		};
		for (var i:int=0; i<length; i++)
		{
			if (!(_mQueue[ i ].flag))
			{
				_sendRequest(_mQueue[ i ], i);
				_lastRequestCount++;
			}
		}
		if (_mQueue.length > 0)
		{
			if (! _timer)
			{
				_timer = new Timer(VK_REQUEST_DELAY);
				_timer.addEventListener (TimerEvent.TIMER, _timerListener);
			}
			if (! _timer.running)
			{
				_timer.start ();
			}
		}
	}
	
	/**
	 * Осуществляет отсроченный вызов запросов из очереди по таймеру.
	 * @param e
	 */
	private function _timerListener (e:TimerEvent):void
	{
		_lastRequestCount = 0;
		_request ();
	}

	
	/**
	 * Деструктор
	 */
	public function dispose ():void
	{
		if (_timer)
		{
			_timer.removeEventListener (TimerEvent.TIMER, _timerListener);
			if (_timer.running)
			{
				_timer.stop ();
			}
			_timer = null;
		}
		_mQueue.length = 0;
		_mQueue = null;
	}
    
    /********************
     * Private methods
     ********************/

    private function _sendRequest(obj:Object, num:int):void {
      var self:Object = this;
	  
	  _mQueue[num].flag = true;

      var request_params: Object = {method: obj.method};
      request_params.api_id = _api_id;
      request_params.format = "JSON";
	  
	  // TODO: снять коммент в боевой версии!!!
	  if (_api_test_mode) {
	  	request_params.test_mode = _api_test_mode;
	  }
	  
	  request_params.v = "3.0";
      if (obj.options.params) {
        for (var i: String in obj.options.params) {
          request_params[i] = obj.options.params[i];
        }
      };
      
      var variables:URLVariables = new URLVariables();
      for (var j: String in request_params) {
        variables[j] = request_params[j];
      }
      variables['sig'] = _generate_signature(request_params);
	  variables['sid'] = _api_sid;
	  
      var request:URLRequest = new URLRequest();
      request.url = _api_url;
      request.method = URLRequestMethod.POST;
      request.data = variables;
      
      var loader:URLLoader = new URLLoader();
      loader.dataFormat = URLLoaderDataFormat.TEXT;
      if (obj.options.onError) {
        loader.addEventListener(IOErrorEvent.IO_ERROR, function():void {
			obj.options.onError("Connection error occured");
        });
        loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function():void {
			obj.options.onError("Security error occured");
        });
      }
      
      loader.addEventListener(Event.COMPLETE, onVKAnswer);
		  
	function onVKAnswer(e:Event):void
	{
        var loader:URLLoader = URLLoader(e.target);
//		trace('------------------------------------------------------------------');
//		trace('REQUEST COMPLETE: \n'+loader.data);
//		trace('------------------------------------------------------------------');
		_mQueue.shift();
		var data: Object = JSON.decode(loader.data);
        if (data.error) 
		{
			obj.options.onError(data.error);
        } 
		else if (obj.options.onComplete && data.response) 
		{
			obj.options.onComplete(data.response);
		  if( _mQueue.length > 0 )
			  _request ();
		  else
			  dispose();
        }
      };
      try {
//		trace("request="+request);
        loader.load(request);
      }
      catch (error:Error) {
//		Cc.info(String(error));
		obj.options.onError(error);
      }
    }

    /**
     * Generates signature
     *
     */
    private function _generate_signature(request_params: Object): String {
      var signature: String = "";
      var sorted_array: Array = new Array();
      for (var key: String in request_params) {
        sorted_array.push(key + "=" + request_params[key]);
      }
      sorted_array.sort();

      // Note: make sure that the signature parameter is not already included in
      //       request_params array.
      for (key in sorted_array) {
        signature += sorted_array[key];
      }
	  if (_viewer_id > 0) 
	  	signature = _viewer_id.toString() + signature;
		
      signature += _api_secret;
      return MD5.encrypt(signature);
    }
  }
}