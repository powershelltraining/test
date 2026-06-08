http://localhost:5005/Help/Topic/S1_ALERT_THRESHOLDS

http://localhost:5005/Settings
Something went wrong

An unexpected error occurred. The error has been logged.
fail: Microsoft.AspNetCore.Diagnostics.ExceptionHandlerMiddleware[1]
      An unhandled exception has occurred while executing the request.
      System.InvalidOperationException: Unable to resolve service for type 'AmazonFBAManager.Data.Services.ISpApiService' while attempting to activate 'AmazonFBAManager.Web.Controllers.SettingsController'.
         at Microsoft.Extensions.DependencyInjection.ActivatorUtilities.ThrowHelperUnableToResolveService(Type type, Type requiredBy)
         at lambda_method82(Closure, IServiceProvider, Object[])
         at Microsoft.AspNetCore.Mvc.Controllers.ControllerFactoryProvider.<>c__DisplayClass6_0.<CreateControllerFactory>g__CreateController|0(ControllerContext controllerContext)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.InvokeInnerFilterAsync()
      --- End of stack trace from previous location ---
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeNextResourceFilter>g__Awaited|25_0(ResourceInvoker invoker, Task lastTask, State next, Scope scope, Object state, Boolean isCompleted)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.Rethrow(ResourceExecutedContextSealed context)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.InvokeFilterPipelineAsync()
      --- End of stack trace from previous location ---
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)
         at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)
         at Microsoft.AspNetCore.Authorization.AuthorizationMiddleware.Invoke(HttpContext context)
