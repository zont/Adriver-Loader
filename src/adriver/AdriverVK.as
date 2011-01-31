package adriver
{
	import flash.events.*;

	import vkontakte.vk.APIConnection;

	public class AdriverVK extends EventDispatcher
	{
		private var vk_parameters:Object;
		private var parameters:Object;
		private var callbackComplete:Function;
		private var callbackError:Function;

		public function init(app_parameters:Object):void
		{
			parameters = app_parameters;
			vk_parameters = parameters.flashVars;
		}

		public function commandGetProfiles(aCallbackComplete:Function, aCallbackError:Function):void
		{
			var api:APIConnection = new APIConnection(vk_parameters);
			var executeCode:String = '\
				var profile = API.getProfiles({"uids": "' + vk_parameters.viewer_id + '", "fields": "bdate,sex,city,country,rate"});\
				var sex = profile[0].sex;\
				var bdate = profile[0].bdate;\
				var city_name = API.getCities({"cids": profile[0].city})[0].name;\
				var country_name = API.getCountries({"cids": profile[0].country})[0].name;\
				return {\
				"sex": sex,\
				"bdate": bdate,\
				"city_name": city_name,\
				"country_name": country_name\
				};';

			callbackComplete = aCallbackComplete;
			callbackError = aCallbackError;
			api.api("execute", {code: executeCode}, onSuccess, onError);
		}

		private function onSuccess(response:Object):void
		{
//			trace("Success", response);

			response.city_name = (response.city_name || '') as String;
			response.country_name = (response.country_name || '') as String;
			response.uid = vk_parameters.viewer_id as String;
			callbackComplete(response);
		}

		private function onError(error:Object):void
		{
//			trace("Error", error);

			parameters.debug("error "+error.error_msg);
			callbackError();
		}

	}
}