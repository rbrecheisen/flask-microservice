import numpy as np

from python.lib.files import download_file
from service.compute.pipelines.base import Pipeline
from service.compute.pipelines.stats.util import load_model
from service.compute.pipelines.util import get_access_token, create_task_dir, delete_task_dir


# ----------------------------------------------------------------------------------------------------------------------
class SupportVectorMachinePrediction(Pipeline):

    def run(self, params):

        # Validate the pipeline parameters
        self.validate_params(params)
        # Request access token from auth service
        token = get_access_token()

        # Create temporary folder for storing a local copy of the input file(s) as
        # well as any intermediate files that are generated by the pipeline.
        task_dir = create_task_dir()

        try:
            # Download classifier. This will be a compressed .tar.gz archive containing
            # the different files saved by joblib.dump(). We first download the file from
            # the storage service, then unpack it and load the classifier object.
            print('Downloading classifier file {} to directory {}'.format(params['classifier_id'], task_dir))
            classifier_file_path = download_file(params['classifier_id'], task_dir, token, extension='.tar.gz')
            print('Loading classifier model from file {}'.format(classifier_file_path))
            classifier = load_model(classifier_file_path)
            # Setup Numpy array to hold the subject data
            X = np.array(params['subjects'])

            # Run classifier with the subject data to be predicted
            print('Running prediction')
            y_pred = classifier.predict(X)
            print('Predicted labels {}'.format(y_pred))

        finally:
            # Delete task directory even if there were errors
            print('Cleaning up task directory')
            delete_task_dir(task_dir)

        # Return predictions for each subject
        return {'predicted_labels': list(y_pred)}

    @staticmethod
    def validate_params(params):

        print('Validating parameters')
        assert 'classifier_id' in params.keys()
        assert 'subjects' in params.keys()
        assert len(params['subjects']) > 0
